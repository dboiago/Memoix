import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database/app_database.dart' hide Recipe;
import '../models/cellar_knowledge_payload.dart';
import '../models/cheese_knowledge_payload.dart';
import '../models/knowledge_payload.dart';
import '../models/modernist_knowledge_payload.dart';
import '../models/pizza_knowledge_payload.dart';
import '../models/sandwich_knowledge_payload.dart';
import '../models/smoking_knowledge_payload.dart';
import '../privacy/pii_scrubber.dart';
import '../utils/payload_hasher.dart';
import 'rag_transmission_client.dart';
import 'supabase_transmission_client.dart';
import '../../features/cellar/models/cellar_entry.dart';
import '../../features/cheese/models/cheese_entry.dart';
import '../../features/modernist/models/modernist_recipe.dart';
import '../../features/pizzas/models/pizza.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/sandwiches/models/sandwich.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/smoking/models/smoking_recipe.dart';

/// Resolves a list of recipe UUIDs to identity records (name + course).
///
/// Passed at construction so [RagTelemetryService] has no direct dependency
/// on [RecipeRepository] (which already imports this service).
typedef PairedRecipeResolver = Future<List<({String name, String course})>>
    Function(List<String> uuids);

/// Decoupled service for the Culinary Intelligence RAG pipeline.
///
/// Validates privacy gates, computes hashes, resolves paired recipes, and
/// delegates transmission to the injected [RagTransmissionClient].
///
/// **Privacy guarantees enforced here:**
/// 1. The individual [Recipe.isShared] flag must be true.
/// 2. The master 'Contribute to Culinary Intelligence' switch must be ON.
/// If either condition fails, the method returns immediately with no side effects.
///
/// **Circular-import note:** [recipe_repository.dart] imports this file, so
/// this file must never import [recipe_repository.dart]. All DB access uses
/// [AppDatabase.instance] directly.
class RagTelemetryService {
  final Ref _ref;
  final RagTransmissionClient _client;
  final PairedRecipeResolver? _pairedRecipeResolver;

  /// [client] defaults to [ConsoleTransmissionClient] when omitted.
  /// [pairedRecipeResolver] resolves paired recipe UUIDs to name+course pairs
  /// so the payload can carry enriched pairing data instead of raw IDs.
  RagTelemetryService(
    this._ref, {
    RagTransmissionClient? client,
    PairedRecipeResolver? pairedRecipeResolver,
  })  : _client = client ?? const ConsoleTransmissionClient(),
        _pairedRecipeResolver = pairedRecipeResolver;

  // ─────────────────────────────────────────────────────────────────────────
  // Standard Recipe
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates privacy gates, computes hashes, resolves pairings, and transmits.
  ///
  /// [recipe] — the fully hydrated recipe to export.
  /// [rawSource] — the original text that produced this recipe. Null for
  /// recipes created or edited manually without an import source.
  Future<void> queueForExport(Recipe recipe, [String? rawSource]) async {
    if (!recipe.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — recipe "${recipe.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    // Compute or reuse the stable lineage hash.
    final lineageHash = await _resolveLineageHash(
      existing: recipe.lineageHash,
      compute: () => PayloadHasher.recipeLineageHash(recipe),
      persistForId: recipe.id,
    );

    final contentHash = PayloadHasher.recipeContentHash(recipe);
    final pairedRecipes = await _resolvePairings(recipe.pairedRecipeIds);
    final metadata = await _buildMetadata();

    final payload = KnowledgePayload(
      recipe: recipe,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
      pairedRecipes: pairedRecipes,
    );
    await _client.transmit(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Modernist
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> queueModernistForExport(
    ModernistRecipe recipe, [
    String? rawSource,
  ]) async {
    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: modernist skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final lineageHash = PayloadHasher.modernistLineageHash(recipe);
    final contentHash = PayloadHasher.modernistContentHash(recipe);
    final pairedRecipes = await _resolvePairings(recipe.pairedRecipeIds);
    final metadata = await _buildMetadata();

    final payload = ModernistKnowledgePayload(
      recipe: recipe,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
      pairedRecipes: pairedRecipes,
    );

    await _client.transmitModernist(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Smoking
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> queueSmokingForExport(
    SmokingRecipe recipe, [
    String? rawSource,
  ]) async {
    if (!recipe.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — smoking recipe "${recipe.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: smoking skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final pairedUuids =
        (jsonDecode(recipe.pairedRecipeIds) as List).cast<String>();
    final lineageHash = PayloadHasher.smokingLineageHash(recipe);
    final contentHash = PayloadHasher.smokingContentHash(recipe);
    final pairedRecipes = await _resolvePairings(pairedUuids);
    final metadata = await _buildMetadata();

    final payload = SmokingKnowledgePayload(
      recipe: recipe,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
      pairedRecipes: pairedRecipes,
    );

    await _client.transmitSmoking(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pizza
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> queuePizzaForExport(Pizza pizza, [String? rawSource]) async {
    if (!pizza.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — pizza "${pizza.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: pizza skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final lineageHash = PayloadHasher.pizzaLineageHash(pizza);
    final contentHash = PayloadHasher.pizzaContentHash(pizza);
    final metadata = await _buildMetadata();

    final payload = PizzaKnowledgePayload(
      pizza: pizza,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
    );

    await _client.transmitPizza(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sandwich
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> queueSandwichForExport(
    Sandwich sandwich, [
    String? rawSource,
  ]) async {
    if (!sandwich.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — sandwich "${sandwich.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: sandwich skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final lineageHash = PayloadHasher.sandwichLineageHash(sandwich);
    final contentHash = PayloadHasher.sandwichContentHash(sandwich);
    final metadata = await _buildMetadata();

    final payload = SandwichKnowledgePayload(
      sandwich: sandwich,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
    );

    await _client.transmitSandwich(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cellar
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes hashes and transmits a [CellarEntry] to the RAG pipeline.
  ///
  /// The individual [CellarEntry.isShared] flag must be true, and the master
  /// Culinary Intelligence switch must also be on.
  Future<void> queueCellarForExport(
    CellarEntry entry, [
    String? rawSource,
  ]) async {
    if (!entry.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — cellar entry "${entry.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: cellar skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final lineageHash = PayloadHasher.cellarLineageHash(entry);
    final contentHash = PayloadHasher.cellarContentHash(entry);
    final metadata = await _buildMetadata();

    final payload = CellarKnowledgePayload(
      entry: entry,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
    );

    await _client.transmitCellar(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cheese
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes hashes and transmits a [CheeseEntry] to the RAG pipeline.
  ///
  /// The individual [CheeseEntry.isShared] flag must be true, and the master
  /// Culinary Intelligence switch must also be on.
  Future<void> queueCheeseForExport(
    CheeseEntry entry, [
    String? rawSource,
  ]) async {
    if (!entry.isShared) {
      debugPrint(
        'RagTelemetryService: skipped — cheese entry "${entry.name}" '
        'has isShared = false.',
      );
      return;
    }

    if (!await _masterSwitchEnabled()) {
      debugPrint(
        'RagTelemetryService: cheese skipped — master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    rawSource = rawSource == null ? null : PiiScrubber.scrub(rawSource);

    final lineageHash = PayloadHasher.cheeseLineageHash(entry);
    final contentHash = PayloadHasher.cheeseContentHash(entry);
    final metadata = await _buildMetadata();

    final payload = CheeseKnowledgePayload(
      entry: entry,
      rawSource: rawSource,
      metadata: metadata,
      lineageHash: lineageHash,
      contentHash: contentHash,
    );

    await _client.transmitCheese(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Backfill
  // ─────────────────────────────────────────────────────────────────────────

  /// Transmits all existing entries to the RAG pipeline when the user first
  /// enables the Culinary Intelligence contribution setting.
  ///
  /// Intended to be called fire-and-forget on the OFF→ON transition of the
  /// master switch. Each domain block is fetched and queued independently;
  /// per-item failures are silently dropped so one bad record cannot abort
  /// the rest of the batch.
  ///
  /// All domain fetchers are injected callbacks because every domain
  /// repository already imports this service — using them directly here
  /// would create a circular dependency.
  ///
  /// The [Recipe.isShared] gate is enforced inside [queueForExport], so
  /// recipes the user has hidden will be silently skipped without any
  /// special handling here. All specialist domain types also enforce their
  /// own [isShared] flag in the respective backfill loops below.
  Future<void> backfillOnOptIn({
    required Future<List<Recipe>> Function() recipeFetcher,
    required Future<List<ModernistRecipe>> Function() modernistFetcher,
    required Future<List<SmokingRecipe>> Function() smokingFetcher,
    required Future<List<Pizza>> Function() pizzaFetcher,
    required Future<List<Sandwich>> Function() sandwichFetcher,
    required Future<List<CellarEntry>> Function() cellarFetcher,
    required Future<List<CheeseEntry>> Function() cheeseFetcher,
  }) async {
    const batchSize = 25;
    // Metadata is identical for every payload in a single backfill run.
    final metadata = await _buildMetadata();

    // Standard recipes — non-shared entries are silently skipped.
    try {
      final recipes = await recipeFetcher();
      final payloads = <KnowledgePayload>[];
      for (final recipe in recipes) {
        if (!recipe.isShared) continue;
        final lineageHash = await _resolveLineageHash(
          existing: recipe.lineageHash,
          compute: () => PayloadHasher.recipeLineageHash(recipe),
          persistForId: recipe.id,
        );
        final contentHash = PayloadHasher.recipeContentHash(recipe);
        final pairedRecipes = await _resolvePairings(recipe.pairedRecipeIds);
        payloads.add(KnowledgePayload(
          recipe: recipe,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
          pairedRecipes: pairedRecipes,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: recipe batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: recipe fetch failed — $e');
    }

    // Modernist recipes.
    try {
      final modernistRecipes = await modernistFetcher();
      final payloads = <ModernistKnowledgePayload>[];
      for (final recipe in modernistRecipes) {
        final lineageHash = PayloadHasher.modernistLineageHash(recipe);
        final contentHash = PayloadHasher.modernistContentHash(recipe);
        final pairedRecipes = await _resolvePairings(recipe.pairedRecipeIds);
        payloads.add(ModernistKnowledgePayload(
          recipe: recipe,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
          pairedRecipes: pairedRecipes,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitModernistBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: modernist batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: modernist fetch failed — $e');
    }

    // Smoking recipes.
    try {
      final smokingRecipes = await smokingFetcher();
      final payloads = <SmokingKnowledgePayload>[];
      for (final recipe in smokingRecipes) {
        if (!recipe.isShared) continue;
        final pairedUuids =
            (jsonDecode(recipe.pairedRecipeIds) as List).cast<String>();
        final lineageHash = PayloadHasher.smokingLineageHash(recipe);
        final contentHash = PayloadHasher.smokingContentHash(recipe);
        final pairedRecipes = await _resolvePairings(pairedUuids);
        payloads.add(SmokingKnowledgePayload(
          recipe: recipe,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
          pairedRecipes: pairedRecipes,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitSmokingBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: smoking batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: smoking fetch failed — $e');
    }

    // Pizzas.
    try {
      final pizzas = await pizzaFetcher();
      final payloads = <PizzaKnowledgePayload>[];
      for (final pizza in pizzas) {
        if (!pizza.isShared) continue;
        final lineageHash = PayloadHasher.pizzaLineageHash(pizza);
        final contentHash = PayloadHasher.pizzaContentHash(pizza);
        payloads.add(PizzaKnowledgePayload(
          pizza: pizza,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitPizzaBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: pizza batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: pizza fetch failed — $e');
    }

    // Sandwiches.
    try {
      final sandwiches = await sandwichFetcher();
      final payloads = <SandwichKnowledgePayload>[];
      for (final sandwich in sandwiches) {
        if (!sandwich.isShared) continue;
        final lineageHash = PayloadHasher.sandwichLineageHash(sandwich);
        final contentHash = PayloadHasher.sandwichContentHash(sandwich);
        payloads.add(SandwichKnowledgePayload(
          sandwich: sandwich,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitSandwichBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: sandwich batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: sandwich fetch failed — $e');
    }

    // Cellar entries.
    try {
      final cellarEntries = await cellarFetcher();
      final payloads = <CellarKnowledgePayload>[];
      for (final entry in cellarEntries) {
        if (!entry.isShared) continue;
        final lineageHash = PayloadHasher.cellarLineageHash(entry);
        final contentHash = PayloadHasher.cellarContentHash(entry);
        payloads.add(CellarKnowledgePayload(
          entry: entry,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitCellarBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: cellar batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: cellar fetch failed — $e');
    }

    // Cheese entries.
    try {
      final cheeseEntries = await cheeseFetcher();
      final payloads = <CheeseKnowledgePayload>[];
      for (final entry in cheeseEntries) {
        if (!entry.isShared) continue;
        final lineageHash = PayloadHasher.cheeseLineageHash(entry);
        final contentHash = PayloadHasher.cheeseContentHash(entry);
        payloads.add(CheeseKnowledgePayload(
          entry: entry,
          rawSource: null,
          metadata: metadata,
          lineageHash: lineageHash,
          contentHash: contentHash,
        ));
      }
      for (var i = 0; i < payloads.length; i += batchSize) {
        final chunk = payloads.sublist(i, min(i + batchSize, payloads.length));
        try {
          await _client.transmitCheeseBatch(chunk);
        } catch (e) {
          debugPrint(
            'RagTelemetryService.backfillOnOptIn: cheese batch at offset $i failed — $e',
          );
        }
      }
    } catch (e) {
      debugPrint('RagTelemetryService.backfillOnOptIn: cheese fetch failed — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Awaits preference load completion, then returns the current master switch
  /// value. This eliminates the startup race where the synchronous [super(false)]
  /// default is read before SharedPreferences has resolved.
  Future<bool> _masterSwitchEnabled() async {
    await _ref.read(contributeToIntelligenceProvider.notifier).ready;
    return _ref.read(contributeToIntelligenceProvider);
  }

  /// Returns the existing [lineageHash] unchanged if set, otherwise computes
  /// a fresh one via [compute] and persists it to the DB for [persistForId].
  Future<String> _resolveLineageHash({
    required String? existing,
    required String Function() compute,
    required int persistForId,
  }) async {
    if (existing != null && existing.isNotEmpty) return existing;
    final hash = compute();
    if (persistForId > 0) {
      try {
        final db = AppDatabase.instance;
        await (db.update(db.recipes)
              ..where((r) => r.id.equals(persistForId)))
            .write(RecipesCompanion(lineageHash: Value(hash)));
      } catch (e) {
        debugPrint('RagTelemetryService: failed to persist lineage hash: $e');
      }
    }
    return hash;
  }

  /// Resolves a list of paired recipe UUIDs to enriched entries.
  ///
  /// Each entry is `{name, course, hash}` where `hash` is a SHA-256 of
  /// `name + course` for that paired recipe (see [PayloadHasher.pairingHash]).
  Future<List<Map<String, String>>> _resolvePairings(
    List<String> uuids,
  ) async {
    if (uuids.isEmpty || _pairedRecipeResolver == null) return [];
    try {
      final resolved = await _pairedRecipeResolver!(uuids);
      return resolved
          .map((p) => {
                'name': p.name,
                'course': p.course,
                'hash': PayloadHasher.pairingHash(p.name, p.course),
              })
          .toList();
    } catch (e) {
      debugPrint('RagTelemetryService: pairing resolution failed: $e');
      return [];
    }
  }

  Future<Map<String, String>> _buildMetadata() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'deviceLocale': Platform.localeName,
    };
  }
}

/// Provider for [RagTelemetryService].
///
/// The [PairedRecipeResolver] callback uses [AppDatabase.instance] directly
/// to avoid a circular import with [recipe_repository.dart].
final ragTelemetryServiceProvider = Provider<RagTelemetryService>((ref) {
  return RagTelemetryService(
    ref,
    client: const SupabaseTransmissionClient(),
    pairedRecipeResolver: (uuids) async {
      final db = AppDatabase.instance;
      try {
        final rows = await db.recipeDao.getRecipesByUuids(uuids);
        final byUuid = {for (final r in rows) r.uuid: r};
        return uuids
            .where((uuid) => byUuid.containsKey(uuid))
            .map((uuid) => (
                  name: byUuid[uuid]!.name,
                  course: byUuid[uuid]!.course,
                ))
            .toList();
      } catch (_) {
        // Skip unresolvable UUIDs — a failed lookup must not abort transmission.
        return [];
      }
    },
  );
});


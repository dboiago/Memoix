Model: huggingface.co/Qwen/Qwen3-14B-GGUF:Q4_K_M
Raw dir: raw-test | Out dir: extracted-test
Needs-review dir: needs-review-test | Cuisine-review dir: cuisine-review-test | Unrecoverable dir: unrecoverable-test | Log dir: logs-test
Warming up Ollama model...
Model ready.
Markdown files in raw/: 303
Extracting [1]: https://ladyandpups.com/2014/09/01/1-hot-summer-2-hot-corns/
  FLAGGED [not-searchable]: 1-hot-summer-2-hot-corns_ladyandpups_4b368f71 -- "cuisine"
Extracting [2]: https://www.okonomikitchen.com/1-pot-curried-coconut-tomato-soup/
  FLAGGED [ingredient-name-embedded-amount]: 1-pot-curried-coconut-tomato-soup-okonomi-kitchen_okonomikitchen_97c8c24c -- "28 Oz Diced Fire Roasted Tomatoes; 13.5 Oz Can Coconut Milk"
Extracting [3]: https://hot-thai-kitchen.com/3-chili-fried-rice/
Extracting [4]: https://www.meilleurduchef.com/en/recipe/christmas-yule-log-three-chocolate-cocoa-nib.html
  FLAGGED [course-unverified-no-grounding]: 3-chocolate-cocoa-nib-yule-log_meilleurduchef_f121a46d -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  FLAGGED [cuisine-from-site-fallback]: 3-chocolate-cocoa-nib-yule-log_meilleurduchef_f121a46d -- "FR"
Extracting [5]: https://www.okonomikitchen.com/diy-3-ingredient-healthy-vegan-cereal/
  FLAGGED [course-unverified-no-grounding]: 3-ingredient-chocolate-hazelnut-cereal-okonomi-kit_okonomikitchen_d647ab97 -- "brunch"
  (recovered 6 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [adapted-dish-cuisine-unresolved]: 3-ingredient-chocolate-hazelnut-cereal-okonomi-kit_okonomikitchen_d647ab97 -- "3-Ingredient Chocolate Hazelnut Cereal"
  FLAGGED [not-searchable]: 3-ingredient-chocolate-hazelnut-cereal-okonomi-kit_okonomikitchen_d647ab97 -- "cuisine"
Extracting [6]: https://omnivorescookbook.com/3-ingredient-fried-shrimp/
  FLAGGED [ingredient-name-embedded-amount]: 3-ingredient-fried-shrimp_omnivorescookbook_1015bea9 -- "And 1 Tablespoon Water"
Extracting [7]: https://omnivorescookbook.com/garlic-broccoli-stir-fry/
Extracting [8]: https://www.diffordsguide.com/cocktails/recipe/30/alabama-slammer
  FLAGGED [not-searchable]: alabama-slammer-cocktail-recipe_diffordsguide_acb1e5f7 -- "cuisine"
Extracting [9]: https://www.diffordsguide.com/cocktails/recipe/4274/alabama-slammer-long
  FLAGGED [not-searchable]: alabama-slammer-long-cocktail-recipe_diffordsguide_d4340239 -- "cuisine"
Extracting [10]: https://www.diffordsguide.com/cocktails/recipe/4275/alabama-slammer-shot
  FLAGGED [not-searchable]: alabama-slammer-shot-cocktail-recipe_diffordsguide_493a3bd7 -- "cuisine"
Extracting [11]: https://www.diffordsguide.com/cocktails/recipe/29/alabama-slammer-straight-up
  FLAGGED [not-searchable]: alabama-slammer-straight-up-cocktail-recipe_diffordsguide_4b2bf22d -- "cuisine"
Extracting [12]: https://barbecuebible.com/recipe/alabama-white-sauce/
  FLAGGED [serves-range]: alabama-white-sauce_barbecuebible_eceb7c8a -- "1.5"
  FLAGGED [no-directions-found]: alabama-white-sauce_barbecuebible_eceb7c8a -- "(whole recipe)"
Extracting [13]: https://punchdrink.com/recipes/alabaster/
  FLAGGED [not-searchable]: alabaster_punchdrink_0dc25b0c -- "cuisine"
Extracting [14]: https://www.greatitalianchefs.com/recipes/amberjack-puttanesca-recipe
  (ldIngredientsRaw has 18 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
  FLAGGED [cuisine-from-site-fallback]: amberjack-with-puttanesca-sauce-recipe_greatitalianchefs_2410b6d2 -- "IT"
Extracting [15]: https://www.greatitalianchefs.com/recipes/americano-cocktail-recipe
  FLAGGED [cuisine-from-site-fallback]: americano-cocktail-recipe_greatitalianchefs_b9562643 -- "IT"
Extracting [16]: https://www.okonomikitchen.com/anpan/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 7 directions from a markdown Method/Instructions section after the model found none)
Extracting [17]: https://woonheng.com/three-cup-san-bei-tofu/
Extracting [18]: https://muybuenoblog.com/caldo-de-res/
Extracting [19]: https://www.chopstickchronicles.com/authentic-shibazuke-pickles/
  FLAGGED [course-unverified-no-grounding]: authentic-shibazuke-pickles-chopstick-chronicles_chopstickchronicles_89cd02f4 -- "pickles"
Extracting [20]: https://www.stadlermade.com/oven-recipes/baba-ganoush-muhammara-flatbreads/
  FLAGGED [not-searchable]: baba-ganoush-muhammara-flatbreads-stadler-made_stadlermade_dce0b458 -- "cuisine"
Extracting [21]: https://annaolson.ca/project/baked-ricotta-salad-with-garden-peas-radish-mint/
  CUISINE-REVIEW: baked-ricotta-salad-with-garden-peas-radish-mint_annaolson_9b70f390 -- site tagged "CA", recipe classified "IT"
Extracting [22]: https://dailycookingquest.com/balado-tempeh-dan-udang.html
  FLAGGED [cuisine-unverified-no-grounding]: balado-tempeh-dan-udang_dailycookingquest_776e2e19 -- "ID"
  CUISINE-REVIEW: balado-tempeh-dan-udang_dailycookingquest_776e2e19 -- cuisine "ID" has no grounding signal to verify against
Extracting [23]: https://dailycookingquest.com/banana-and-papaya-juice.html
  FLAGGED [cuisine-unverified-no-grounding]: banana-and-papaya-juice_dailycookingquest_51700a12 -- "ID"
  CUISINE-REVIEW: banana-and-papaya-juice_dailycookingquest_51700a12 -- cuisine "ID" has no grounding signal to verify against
Extracting [24]: https://bakefromscratch.com/banana-pudding-stuffed-cookies/
  FLAGGED [not-searchable]: banana-pudding-stuffed-cookies-bake-from-scratch_bakefromscratch_c63058e9 -- "cuisine"
Extracting [25]: https://amazingribs.com/tested-recipes/hamburger-sloppy-joe-salisbury-steak-recipes/beef-and-mushroom-blended-burgers/
Extracting [26]: https://www.koreanbapsang.com/beef-doenjang-jjigae/
  FLAGGED [course-unverified-no-grounding]: beef-doenjang-jjigae_koreanbapsang_66354e27 -- "mains"
  FLAGGED [ingredient-name-embedded-amount]: beef-doenjang-jjigae_koreanbapsang_66354e27 -- "Zucchini About 3 Ounces"
Extracting [27]: https://thewoksoflife.com/beef-rendang/
  FLAGGED [course-unverified-no-grounding]: beef-rendang_thewoksoflife_19449d59 -- "mains"
Extracting [28]: https://ladyandpups.com/2017/10/30/beef-tartare-with-sea-urchin-from-the-neighborhood/
  FLAGGED [cuisine-unverified-no-grounding]: beef-tartare-with-sea-urchin-from-the-neighborhood_ladyandpups_8343fb02 -- "FR"
  CUISINE-REVIEW: beef-tartare-with-sea-urchin-from-the-neighborhood_ladyandpups_8343fb02 -- cuisine "FR" has no grounding signal to verify against
Extracting [29]: https://khymos.org/2009/01/31/tgrwt-14-beer-sorbet-with-soy-marinated-melon/
  FLAGGED [not-searchable]: beer-sorbet-with-soy-marinated-melon-khymos_khymos_35f235e6 -- "cuisine"
Extracting [30]: https://amazingribs.com/tested-recipes/beef-and-bison-recipes/smoked-brisket-texas-style/
Extracting [31]: https://hot-thai-kitchen.com/hong-kong-mango-pancake/
  FLAGGED [course-unverified-no-grounding]: better-hong-kong-mango-pancake-dim-sum-style-pai-s_hot-thai-kitchen_48e8eec3 -- "desserts"
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: better-hong-kong-mango-pancake-dim-sum-style-pai-s_hot-thai-kitchen_48e8eec3 -- "(whole recipe)"
Extracting [32]: https://www.bongeats.com/recipe/bhetki-paturi
  FLAGGED [course-unverified-no-grounding]: bhetki-paturi-recipe-by-bong-eats_bongeats_b9ffaa76 -- "mains"
  (recovered 18 directions from a markdown Method/Instructions section after the model found none)
Extracting [33]: https://www.cookwithmanali.com/bhindi-do-pyaza/
Extracting [34]: https://www.cookwithmanali.com/bhindi-kadhi/
  FLAGGED [course-unverified-no-grounding]: bhindi-kadhi_cookwithmanali_9bcadcb9 -- "mains"
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
Extracting [35]: https://www.cookwithmanali.com/bhindi-masala-okra-stir-fry/
Extracting [36]: https://punchdrink.com/recipes/bhoomi/
  FLAGGED [not-searchable]: bhoomi_punchdrink_ff34cf00 -- "cuisine"
Extracting [37]: https://ladyandpups.com/2017/06/15/bialy-stuffed-w-cream-cheese-and-honey-dates/
  FLAGGED [cuisine-unverified-no-grounding]: bialy-stuffed-w-cream-cheese-and-honey-dates_ladyandpups_6f13b6a4 -- "PL"
  CUISINE-REVIEW: bialy-stuffed-w-cream-cheese-and-honey-dates_ladyandpups_6f13b6a4 -- cuisine "PL" has no grounding signal to verify against
Extracting [38]: https://pastryartsmag.com/places/bianco-latte-in-brooklyn-ny/
  SKIP [empty-content]: bianco-latte-in-brooklyn-ny-pastry-arts_pastryartsmag_5acde59f -- No ingredients or directions extracted
Extracting [38]: https://www.greatbritishchefs.com/recipes/biancomangiare-almond-milk-pudding-recipe
  FLAGGED [cuisine-from-site-fallback]: biancomangiare-almond-milk-pudding-recipe_greatbritishchefs_c05d4342 -- "GB"
Extracting [39]: https://www.chinasichuanfood.com/biang-biang-mian-biang-biang-noodles/
  FLAGGED [compound-amount-detected]: biang-biang-mian-biang-biang-noodles_chinasichuanfood_f4a999b3 -- "130 ml to 140ml water"
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: biang-biang-mian-biang-biang-noodles_chinasichuanfood_f4a999b3 -- "(whole recipe)"
Extracting [40]: https://www.greatbritishchefs.com/recipes/biang-biang-noodles-gochujang-braised-pork-recipe
  FLAGGED [cuisine-from-site-fallback]: biang-biang-noodles-with-gochujang-braised-pork-an_greatbritishchefs_6db71847 -- "GB"
Extracting [41]: https://omnivorescookbook.com/biang-biang-noodles/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 8 directions from a markdown Method/Instructions section after the model found none)
Extracting [42]: https://www.greatitalianchefs.com/recipes/bio-eggs-asparagus-recipe
  FLAGGED [cuisine-from-site-fallback]: bio-eggs-with-asparagus-recipe_greatitalianchefs_be4e962e -- "IT"
Extracting [43]: https://www.baking-sense.com/2021/07/15/blackberry-lavender-preserves/
Extracting [44]: https://pastryartsmag.com/recipes/blueberry-pearls-by-venia-flessa/
  FLAGGED [not-searchable]: blueberry-pearls-by-venia-flessa-pastry-arts_pastryartsmag_66f20887 -- "cuisine"
Extracting [45]: http://joepastry.com/2015/blueberry-pie-recipe-2/
  FLAGGED [cuisine-unverified-no-grounding]: blueberry-pie-recipe-joe-pastry_joepastry_1f83e170 -- "US"
  CUISINE-REVIEW: blueberry-pie-recipe-joe-pastry_joepastry_1f83e170 -- cuisine "US" has no grounding signal to verify against
Extracting [46]: https://www.lacucinaitaliana.com/recipe/cakes-and-desserts/blueberry-pie
  FLAGGED [course-unverified-no-grounding]: blueberry-pie_lacucinaitaliana_dfe1b855 -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
Extracting [47]: https://www.baking-sense.com/2023/07/05/blueberry-pound-cake/
Extracting [48]: https://pastryartsmag.com/recipes/brazilian-vanilla-caramel-and-jabuticaba-mille-feuille-by-renan-zacchi/
  SKIP [extract-error]: brazilian-vanilla-caramel-and-jabuticaba-mille-feu_pastryartsmag_0916e16c -- fetch failed
Extracting [48]: https://pastryartsmag.com/general/brown-butter-beurre-noisette-usage-in-viennoiserie-and-other-barrier-methods/
  FLAGGED [long-name]: brown-butter-beurre-noisette-usage-in-viennoiserie_pastryartsmag_ee71b7a2 -- "Brown Butter (Beurre Noisette) Usage in Viennoiserie and Other Barrier Methods"
  SKIP [empty-content]: brown-butter-beurre-noisette-usage-in-viennoiserie_pastryartsmag_ee71b7a2 -- No ingredients or directions extracted
Extracting [48]: https://www.stadlermade.com/oven-recipes/brussel-sprouts/
  FLAGGED [cuisine-unverified-no-grounding]: brussel-sprouts-stadler-made_stadlermade_65b2c749 -- "IT"
  CUISINE-REVIEW: brussel-sprouts-stadler-made_stadlermade_65b2c749 -- cuisine "IT" has no grounding signal to verify against
Extracting [49]: https://dailycookingquest.com/brussels-sprouts-and-garlic-stir-fry.html
Extracting [50]: https://ladyandpups.com/2014/05/16/bunker-crack-slurp-eng/
  FLAGGED [ingredient-name-embedded-amount]: bunker-crack-slurp_ladyandpups_c406eef1 -- "Or 4 Medium Asian Shallots"
  FLAGGED [not-searchable]: bunker-crack-slurp_ladyandpups_c406eef1 -- "cuisine"
Extracting [51]: https://www.theboywhobakes.co.uk/recipes/2017/2/22/buttermilk-panna-cotta-with-rose-roasted-rhubarb
  FLAGGED [cuisine-from-site-fallback]: buttermilk-panna-cotta-with-rose-roasted-rhubarb-t_theboywhobakes_2335a808 -- "GB"
Extracting [52]: https://japan.recipetineats.com/cafe-style-japanese-sandwiches/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [ingredient-name-embedded-amount]: cafe-style-japanese-sandwiches_japan_79203af4 -- "70g/2.5oz
                                                                                                                       chicken
                                                                                steamed; 30g/1.1oz
                                                                                                                       celery
                                                                                finely Sliced"
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
Extracting [53]: https://muybuenoblog.com/skull-confetti-filled-eggs/
  FLAGGED [course-unverified-no-grounding]: calavera-cascarones-skull-confetti-filled-eggs_muybuenoblog_fddc5361 -- "sides"
  FLAGGED [cuisine-from-site-fallback]: calavera-cascarones-skull-confetti-filled-eggs_muybuenoblog_fddc5361 -- "MX"
Extracting [54]: https://thewoksoflife.com/campfire-curry-ramen/
  FLAGGED [course-unverified-no-grounding]: campfire-curry-ramen_thewoksoflife_ccc6d944 -- "mains"
Extracting [55]: https://pastryartsmag.com/recipes/caramelized-apple-mille-feuille-by-sylvain-fond/
  FLAGGED [not-searchable]: caramelized-apple-mille-feuille-by-sylvain-fond-pa_pastryartsmag_36702993 -- "cuisine"
Extracting [56]: https://blog.modernistpantry.com/recipes/caramelized-cornbread-with-maple-bacon-butter/
  FLAGGED [not-searchable]: caramelized-cornbread-with-maple-bacon-butter-kitc_blog_610d455c -- "cuisine"
Extracting [57]: https://barbecuebible.com/recipe/caveman-slaw-ember-charred-cabbage-with-caraway-and-mint/
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-from-site-fallback]: caveman-slaw-ember-charred-cabbage-with-caraway-an_barbecuebible_9dacb03e -- "US"
Extracting [58]: https://barbecuebible.com/recipe/caveman-strip-steaks-bell-pepper-pan-fry-smoky-potato-salad/
  (recovered 18 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-from-site-fallback]: caveman-strip-steaks-with-bell-pepper-pan-fry-and-_barbecuebible_9f7aeb3c -- "US"
Extracting [59]: https://barbecuebible.com/2009/06/30/caveman-t-bone-hits-the-today-show/
  SKIP [empty-content]: caveman-t-bone-hits-the-today-show_barbecuebible_5e59895b -- No ingredients or directions extracted
Extracting [59]: https://barbecuebible.com/recipe/caveman-t-bone-steak-with-smashed-potatoes/
  (recovered 9 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-from-site-fallback]: caveman-t-bone-steak-with-smashed-potatoes_barbecuebible_3fe41a1c -- "US"
Extracting [60]: https://barbecuebible.com/recipe/caveman-t-bones-with-bell-pepper-hash/
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
Extracting [61]: https://barbecuebible.com/recipe/caveman-t-bones-hellfire-hot-sauce/
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
Extracting [62]: https://barbecuebible.com/2017/01/20/celebrate-grilled-cheese-halloumi/
  CUISINE-REVIEW: celebrate-grilled-cheese-halloumi_barbecuebible_063f420c -- site tagged "US", recipe classified "CY"
Extracting [63]: https://ottolenghi.co.uk/pages/recipes/celebration-tah-chin-chicken-spinach
  FLAGGED [not-searchable]: celebration-tah-chin-with-chicken-and-spinach-otto_ottolenghi_c6490495 -- "cuisine"
Extracting [64]: https://www.greatbritishchefs.com/recipes/celebration-trifle-recipe
  FLAGGED [cuisine-from-site-fallback]: celebration-trifle-recipe_greatbritishchefs_b9450fdb -- "GB"
Extracting [65]: https://www.greatbritishchefs.com/recipes/celeriac-apple-saint-agur-salad-recipe
  FLAGGED [cuisine-from-site-fallback]: celeriac-and-apple-salad-with-saint-agur-dressing_greatbritishchefs_6d56c487 -- "GB"
Extracting [66]: https://www.thestaffcanteen.com/chefs-recipes/celeriac-and-kale-sausage-stew
  FLAGGED [not-searchable]: celeriac-and-kale-sausage-stew_thestaffcanteen_6e3b4817 -- "cuisine"
Extracting [67]: https://www.greatbritishchefs.com/recipes/celeriac-gruyere-agnolotti-recipe
  FLAGGED [cuisine-from-site-fallback]: celeriac-and-le-gruy-re-aop-agnolotti-recipe_greatbritishchefs_42e2ebc8 -- "GB"
Extracting [68]: https://ottolenghi.co.uk/pages/recipes/celeriac-lentils-hazelnuts-mint
  FLAGGED [not-searchable]: celeriac-and-lentils-with-hazelnuts-mint-ottolengh_ottolenghi_a3d8d8a3 -- "cuisine"
Extracting [69]: https://www.thestaffcanteen.com/chefs-recipes/celeriac-and-morel-gratin
  FLAGGED [not-searchable]: celeriac-and-morel-gratin_thestaffcanteen_115eaff6 -- "cuisine"
Extracting [70]: https://www.greatbritishchefs.com/recipes/celeriac-potato-dauphinoise-recipe
  CUISINE-REVIEW: celeriac-and-potato-dauphinoise-recipe_greatbritishchefs_d1e4ceda -- site tagged "GB", recipe classified "FR"
Extracting [71]: https://pastryartsmag.com/recipes/celery-mint-honeydew-white-chocolate-by-angel-r-betancourt/
  FLAGGED [not-searchable]: celery-mint-honeydew-white-chocolate-by-angel-r-be_pastryartsmag_e448ec2d -- "cuisine"
Extracting [72]: https://www.diffordsguide.com/cocktails/recipe/5266/celery-nome
  FLAGGED [not-searchable]: celery-nome-cocktail-recipe_diffordsguide_1d15ee0b -- "cuisine"
Extracting [73]: https://www.greatbritishchefs.com/recipes/celery-potato-salt-cod-recipe
  FLAGGED [cuisine-from-site-fallback]: celery-potato-and-salt-cod-salad-recipe_greatbritishchefs_0ab4a1ef -- "GB"
Extracting [74]: https://www.lacucinaitaliana.com/recipe/pasta/celery-ravioli-in-monkfish-stew
  FLAGGED [course-unverified-no-grounding]: celery-ravioli-in-monkfish-stew_lacucinaitaliana_6be53144 -- "mains"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
Extracting [75]: https://www.davidlebovitz.com/celery-root-remoulade-celeri-rem/
Extracting [76]: https://www.davidlebovitz.com/celery-root-soup/
  FLAGGED [ingredient-name-embedded-amount]: celery-root-soup-david-lebovitz_davidlebovitz_902a8e58 -- "1/2 Teaspoons Freshly-ground White Pepper; Scant 1/8 Teaspoon Chili Powder"
Extracting [77]: https://www.baking-sense.com/2022/02/03/chai-tea-ice-cream/
Extracting [78]: https://ladyandpups.com/2016/02/17/charred-cauliflower-w-garlics-tabasco-vinegar/
  FLAGGED [not-searchable]: charred-cauliflower-w-garlics-tabasco-vinegar_ladyandpups_6e064ff2 -- "cuisine"
Extracting [79]: https://bakingsteel.com/blogs/recipes/how-to-make-cheesy-bread-sticks-on-a-baking-steel
  (recovered 6 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [not-searchable]: cheese-breadsticks-recipe-mozzarella-stuffed-450-f_bakingsteel_19748729 -- "cuisine"
Extracting [80]: https://www.baking-sense.com/2019/06/27/sour-cherry-crumb-pie/
Extracting [81]: https://www.theperfectloaf.com/sourdough-discard-oatmeal-raisin-cookies/
Extracting [82]: https://www.bongeats.com/recipe/chicken-curry
  FLAGGED [course-unverified-no-grounding]: chicken-curry-recipe-by-bong-eats_bongeats_cb0f775a -- "mains"
  (recovered 16 directions from a markdown Method/Instructions section after the model found none)
Extracting [83]: https://muybuenoblog.com/chiles-en-nogada-stuffed-poblano-chiles-with-walnut-sauce/
Extracting [84]: https://maunikagowardhan.co.uk/cook-in-a-curry/chilli-paneer-fry-indian-chinese-style/
  FLAGGED [course-unverified-no-grounding]: chilli-paneer-fry-indian-recipes-maunika-gowardhan_maunikagowardhan_23c4e1be -- "mains"
  FLAGGED [ingredient-placeholder-fabricated]: chilli-paneer-fry-indian-recipes-maunika-gowardhan_maunikagowardhan_23c4e1be -- "Batter Ingredients"
Extracting [85]: https://www.chinasichuanfood.com/chinese-chive-and-egg-stir-fry/
Extracting [86]: https://modernistbread.com/chocolate-cherry-sourdough/
  SKIP [empty-content]: chocolate-and-cherry-sourdough-modernist-bread_modernistbread_b859321f -- No ingredients or directions extracted
Extracting [86]: https://pastryartsmag.com/recipes/chocolate-brandy-by-manuel-bouillet/
  FLAGGED [not-searchable]: chocolate-brandy-by-manuel-bouillet-pastry-arts_pastryartsmag_2e27dfa7 -- "cuisine"
Extracting [87]: https://www.meilleurduchef.com/en/recipe/chocolate-easter-bunny.html
  FLAGGED [course-unverified-no-grounding]: chocolate-easter-bunny_meilleurduchef_20f7fa9e -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  FLAGGED [cuisine-from-site-fallback]: chocolate-easter-bunny_meilleurduchef_20f7fa9e -- "FR"
Extracting [88]: https://www.greatbritishchefs.com/recipes/christmas-pudding-recipe-brandy-butter
  FLAGGED [cuisine-from-site-fallback]: christmas-pudding-recipe-with-brandy-butter_greatbritishchefs_994a3fee -- "GB"
Extracting [89]: https://www.thestaffcanteen.com/chefs-recipes/Christmas-pudding-souffle--2
  FLAGGED [cuisine-unverified-no-grounding]: christmas-pudding-souffl-eacute_thestaffcanteen_33455ffc -- "GB"
  CUISINE-REVIEW: christmas-pudding-souffl-eacute_thestaffcanteen_33455ffc -- cuisine "GB" has no grounding signal to verify against
Extracting [90]: https://punchdrink.com/recipes/chrysanthemum-2/
  FLAGGED [not-searchable]: chrysanthemum-2_punchdrink_a68dd3cf -- "cuisine"
Extracting [91]: https://amazingribs.com/tested-recipes/dessert-recipes/purple-passion-grape-pie-recipe/
Extracting [92]: https://modernistcuisine.com/recipes/crispy-chicken-wings-korean-style/
  FLAGGED [cuisine-unverified-no-grounding]: crispy-chicken-wings-korean-style-modernist-cuisin_modernistcuisine_74c6c0f7 -- "KR"
  CUISINE-REVIEW: crispy-chicken-wings-korean-style-modernist-cuisin_modernistcuisine_74c6c0f7 -- cuisine "KR" has no grounding signal to verify against
Extracting [93]: https://lyres.com/en-uk/products/lyres-cucumber-and-basil-margarita-twist
  FLAGGED [not-searchable]: cucumber-and-basil-margarita-twist_lyres_50d86a45 -- "cuisine"
Extracting [94]: https://www.koreanbapsang.com/oi-kimchi-cucumber-kimchi-and-blog/
Extracting [95]: https://itdoesnttastelikechicken.com/dog-birthday-cake-recipe/
  FLAGGED [adapted-dish-cuisine-unresolved]: dog-birthday-cake-recipe-easy-vegan-dog-friendly_itdoesnttastelikechicken_cfad1c7d -- "Dog Birthday Cake"
  FLAGGED [not-searchable]: dog-birthday-cake-recipe-easy-vegan-dog-friendly_itdoesnttastelikechicken_cfad1c7d -- "cuisine"
Extracting [96]: https://www.bongeats.com/recipe/doodh-potol
  (recovered 6 directions from a markdown Method/Instructions section after the model found none)
Extracting [97]: https://vickypham.com/blog/bok-choy-oyster-sauce/
  CUISINE-REVIEW: easy-bok-choy-stir-fry-with-oyster-sauce-vicky-pha_vickypham_3a6738f3 -- site tagged "VN", recipe classified "CN"
Extracting [98]: https://www.nyonyacooking.com/snaps/y6ah6LUOm1
  SKIP [empty-content]: easy-butter-cake_nyonyacooking_430d2f18 -- No ingredients or directions extracted
Extracting [98]: https://ranveerbrar.com/recipes/dhaba-style-mutton-keema/
  (ldIngredientsRaw has 5 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
Extracting [99]: https://ranveerbrar.com/recipes/fish-cakes/
  (ldIngredientsRaw has only 1 entry -- too few to trust, falling back to whole-page extraction)
  FLAGGED [cuisine-from-site-fallback]: easy-fish-cakes-recipe-ranveer-brar_ranveerbrar_f0848289 -- "IN"
Extracting [100]: https://itdoesnttastelikechicken.com/easy-homemade-lentil-tofu/
Extracting [101]: https://ranveerbrar.com/recipes/lauki-ka-halwa/
  (ldIngredientsRaw has 3 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
Extracting [102]: https://ranveerbrar.com/recipes/onion-tomato-masala-dal-tadka/
  (ldIngredientsRaw has 2 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
Extracting [103]: https://woonheng.com/easy-vegan-sambal/
  FLAGGED [ingredient-name-embedded-amount]: easy-vegan-sambal-chili-paste-spicy-and-gluten-fre_woonheng_c70e3605 -- "Shallot About 100g; Bulb Garlic About 6-8 Cloves; A Few Slices of Ginger About 8 G; Oil for Blending and Cooking *separated to 1/2 Cup + 1/4 Cup"
  FLAGGED [cuisine-unverified-no-grounding]: easy-vegan-sambal-chili-paste-spicy-and-gluten-fre_woonheng_c70e3605 -- "MY"
Extracting [104]: https://www.cookwithmanali.com/eggless-french-toast/
  CUISINE-REVIEW: eggless-french-toast_cookwithmanali_f377d9ae -- site tagged "IN", recipe classified "US"
Extracting [105]: https://www.cookwithmanali.com/eggless-fruit-cake/
  CUISINE-REVIEW: eggless-fruit-cake_cookwithmanali_db9d5346 -- site tagged "IN", recipe classified "US"
Extracting [106]: https://www.cookwithmanali.com/eggless-kaju-pista-cookies/
  FLAGGED [course-unverified-no-grounding]: eggless-kaju-pista-cookies-cashew-pistachio-cookie_cookwithmanali_d572fb86 -- "breads"
Extracting [107]: https://www.nyonyacooking.com/recipes/eggless-kaya-pumpkin-coconut-jam~P5NakKKpcK
Extracting [108]: https://www.cookwithmanali.com/eggless-lemon-cake/
  FLAGGED [compound-amount-detected]: eggless-lemon-cake_cookwithmanali_42f7f730 -- "1/2 cup + 2 tablespoons plain yogurt, 150 grams, at room temperature"
Extracting [109]: https://www.cookwithmanali.com/eggless-marble-cake/
  FLAGGED [compound-amount-detected]: eggless-marble-cake_cookwithmanali_8c6111f8 -- "1 tablespoon + 1 teaspoon white vinegar, 15 ml + 5 ml"
Extracting [110]: https://muybuenoblog.com/elote-en-vaso-corn-in-a-cup/
Extracting [111]: https://insaneinthebrine.com/kosher-garlic-dills/
  FLAGGED [ingredient-name-embedded-amount]: everything-you-need-to-know-to-make-kosher-garlic-_insaneinthebrine_367fa4d6 -- "Morton Canning Salt (or Any Non-iodized, Additive-free Salt); Use 3 Tbsp If You Like Salty Pickles"
  FLAGGED [no-directions-found]: everything-you-need-to-know-to-make-kosher-garlic-_insaneinthebrine_367fa4d6 -- "(whole recipe)"
  FLAGGED [not-searchable]: everything-you-need-to-know-to-make-kosher-garlic-_insaneinthebrine_367fa4d6 -- "cuisine"
Extracting [112]: https://www.greatitalianchefs.com/recipes/sea-bream-fettuccine-recipe
  FLAGGED [cuisine-from-site-fallback]: fettuccine-with-sea-bream-recipe_greatitalianchefs_7bb3affc -- "IT"
Extracting [113]: https://www.theperfectloaf.com/fig-and-fennel-sourdough-plus-a-little-family-history/
  FLAGGED [ingredient-placeholder-fabricated]: fig-and-fennel-sourdough-the-perfect-loaf_theperfectloaf_b6f10578 -- "Mix These Ingredients by Hand Until All the Dry Bits Are Incorporated"
  FLAGGED [ingredient-name-embedded-amount]: fig-and-fennel-sourdough-the-perfect-loaf_theperfectloaf_b6f10578 -- "Add 800g of Your Water (the Rest Is Reserved Until Later When We Add in the Levain & Salt After the Autolyse)"
  FLAGGED [no-directions-found]: fig-and-fennel-sourdough-the-perfect-loaf_theperfectloaf_b6f10578 -- "(whole recipe)"
  FLAGGED [not-searchable]: fig-and-fennel-sourdough-the-perfect-loaf_theperfectloaf_b6f10578 -- "cuisine"
Extracting [114]: https://www.chopstickchronicles.com/fried-cauliflower-karaage/
Extracting [115]: https://khymos.org/2009/05/07/tgfwt-17-frozen-rosy-apple-foam/
  FLAGGED [not-searchable]: frozen-rosy-apple-foam-khymos_khymos_6efff446 -- "cuisine"
Extracting [116]: https://modernistcuisine.com/recipes/garlic-confit/
  SKIP [empty-content]: garlic-confit-modernist-cuisine_modernistcuisine_716d3aa8 -- No ingredients or directions extracted
Extracting [116]: https://khymos.org/2010/12/17/gelling-ketchup-with-horseradish/
  FLAGGED [not-searchable]: gelling-ketchup-with-horseradish-khymos_khymos_eb5b3207 -- "cuisine"
Extracting [117]: https://khymos.org/2014/02/24/ginger-milk-curd/
  FLAGGED [cuisine-unverified-no-grounding]: ginger-milk-curd-khymos_khymos_2c06d778 -- "IN"
  CUISINE-REVIEW: ginger-milk-curd-khymos_khymos_2c06d778 -- cuisine "IN" has no grounding signal to verify against
Extracting [118]: https://khymos.org/2010/05/16/tgrwt-21-gnocchi-with-peanuts-and-sage/
  FLAGGED [not-searchable]: gnocchi-with-peanuts-and-sage-khymos_khymos_7c87c906 -- "cuisine"
Extracting [119]: https://www.diffordsguide.com/cocktails/recipe/36058/go-your-own-way
  SKIP [empty-content]: go-your-own-way-cocktail-recipe-master-bartender_diffordsguide_709f6500 -- No ingredients or directions extracted
Extracting [119]: https://japan.recipetineats.com/goya-chanpuru-bitter-melon-stir-fry-okinawan-style/goya/
  FLAGGED [course-unverified-no-grounding]: goya-recipetin-japan_japan_89ed15f1 -- "mains"
  SKIP [empty-content]: goya-recipetin-japan_japan_89ed15f1 -- No ingredients or directions extracted
Extracting [119]: https://www.diffordsguide.com/cocktails/recipe/32084/gpt-shot
  SKIP [empty-content]: gpt-shot-cocktail-recipe-discerning-drinker_diffordsguide_9f3fb4ba -- No ingredients or directions extracted
Extracting [119]: https://spanishsabores.com/eat-late-in-granada/
  FLAGGED [long-name]: grab-a-late-night-bite-at-these-fantastic-places-t_spanishsabores_e85f70e6 -- "Grab a Late Night Bite at These Fantastic Places to Eat Late in Granada"
  SKIP [empty-content]: grab-a-late-night-bite-at-these-fantastic-places-t_spanishsabores_e85f70e6 -- No ingredients or directions extracted
Extracting [119]: https://spanishsabores.com/best-views-of-granada/
  SKIP [empty-content]: grab-your-camera-and-head-to-these-places-to-enjoy_spanishsabores_35fbe01d -- No ingredients or directions extracted
Extracting [119]: https://punchdrink.com/recipes/graceful-old-fashioned/
  FLAGGED [not-searchable]: graceful-old-fashioned_punchdrink_17282df5 -- "cuisine"
Extracting [120]: https://hot-thai-kitchen.com/jab-chai/
Extracting [121]: https://www.thebreadshebakes.com/2016/07/grape-bread-recipe/
  (recovered 9 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-unverified-no-grounding]: grape-bread-recipe-the-bread-she-bakes_thebreadshebakes_496d0d7f -- "FR"
  CUISINE-REVIEW: grape-bread-recipe-the-bread-she-bakes_thebreadshebakes_496d0d7f -- cuisine "FR" has no grounding signal to verify against
Extracting [122]: https://bakingsteel.com/blogs/recipes/grilled-vegetable-and-chickpea-salad-with-sunflower-sesame-dressing
  FLAGGED [no-directions-found]: grilled-vegetable-and-chickpea-salad_bakingsteel_09fc79fa -- "(whole recipe)"
  FLAGGED [not-searchable]: grilled-vegetable-and-chickpea-salad_bakingsteel_09fc79fa -- "cuisine"
Extracting [123]: https://www.koreanbapsang.com/gul-tteokguk-oyster-rice-cake-soup/
  FLAGGED [ingredient-name-embedded-amount]: gul-tteokguk-oyster-rice-cake-soup_koreanbapsang_8d358ea9 -- "3-inch Square Dried Kelp Dashima - Optional"
Extracting [124]: https://annaolson.ca/project/halloween-spider-macarons/
  FLAGGED [cuisine-from-site-fallback]: halloween-spider-macarons-anna-olson_annaolson_b5c6ca13 -- "CA"
Extracting [125]: https://pastryartsmag.com/recipes/hazelnut-chocolate-torte-by-aleksandra-crapanzano/
  FLAGGED [not-searchable]: hazelnut-chocolate-torte-by-aleksandra-crapanzano-_pastryartsmag_fb1b4f6f -- "cuisine"
Extracting [126]: https://www.chopstickchronicles.com/hoshigaki-dried-persimmon/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
Extracting [127]: https://www.chinasichuanfood.com/hot-oyster-noodles/
Extracting [128]: https://www.greatbritishchefs.com/recipes/ice-cream-sandwich-recipe
  FLAGGED [cuisine-from-site-fallback]: ice-cream-sandwich-recipe_greatbritishchefs_21ac9b80 -- "GB"
Extracting [129]: https://www.meilleurduchef.com/en/recipe/vacherin-meringue-ice-cream.html
  FLAGGED [course-unverified-no-grounding]: ice-cream-vacherin_meilleurduchef_cc5c0af3 -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  FLAGGED [cuisine-from-site-fallback]: ice-cream-vacherin_meilleurduchef_cc5c0af3 -- "FR"
Extracting [130]: https://blog.modernistpantry.com/advice/ice-cream-with-no-machine/
  SKIP [empty-content]: ice-cream-with-no-machine-kitchen-alchemy_blog_378e7c56 -- No ingredients or directions extracted
Extracting [130]: https://www.chinasichuanfood.com/iced-lemon-tea/
  FLAGGED [cuisine-from-site-fallback]: iced-lemon-tea_chinasichuanfood_ca05c692 -- "CN"
Extracting [131]: https://barbecuebible.com/recipe/icicle-radish-salad/
  (recovered 2 directions from a markdown Method/Instructions section after the model found none)
Extracting [132]: https://barbecuebible.com/recipe/indian-tandoori-marinade/
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
  CUISINE-REVIEW: indian-tandoori-marinade_barbecuebible_4fa24771 -- site tagged "US", recipe classified "IN"
Extracting [133]: https://www.okonomikitchen.com/sweet-potato-cheese-mochi/
  FLAGGED [ingredient-name-embedded-amount]: japanese-sweet-potato-cheese-mochi-okonomi-kitchen_okonomikitchen_d7b1ed73 -- "2/3-1 Cup (70-90 G) Shredded Cheese (gouda, Mozzarella, Sharp White Cheddar or Cheddar Cheese)"
Extracting [134]: https://www.cookwithmanali.com/kaju-pista-roll/
Extracting [135]: https://www.chopstickchronicles.com/kakeudon/
  FLAGGED [course-unverified-no-grounding]: kakeudon-chopstick-chronicles_chopstickchronicles_74b69931 -- "mains"
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 7 directions from a markdown Method/Instructions section after the model found none)
Extracting [136]: https://www.diffordsguide.com/cocktails/recipe/40219/kakheti-long
  SKIP [empty-content]: kakheti-long-cocktail-recipe-discerning-drinker_diffordsguide_bbb2431b -- No ingredients or directions extracted
Extracting [136]: https://japan.recipetineats.com/deep-fried-crumbed-oysters-kaki-fry/kaki_fry_ingredients_8077/
  FLAGGED [course-unverified-no-grounding]: kaki-fry-ingredients-8077-recipetin-japan_japan_39d7d7ef -- "mains"
  SKIP [empty-content]: kaki-fry-ingredients-8077-recipetin-japan_japan_39d7d7ef -- No ingredients or directions extracted
Extracting [136]: https://japan.recipetineats.com/deep-fried-crumbed-oysters-kaki-fry/kaki_fry_step-by-step/
  FLAGGED [course-unverified-no-grounding]: kaki-fry-step-by-step-recipetin-japan_japan_9b516096 -- "mains"
  SKIP [empty-content]: kaki-fry-step-by-step-recipetin-japan_japan_9b516096 -- No ingredients or directions extracted
Extracting [136]: https://japan.recipetineats.com/kakiage-mixed-vegetable-tempura/
Extracting [137]: https://www.greatbritishchefs.com/recipes/kakiage-tempura-hojicha-salt-recipe
  CUISINE-REVIEW: kakiage-tempura-recipe_greatbritishchefs_200cad6b -- site tagged "GB", recipe classified "JP"
Extracting [138]: https://japan.recipetineats.com/kakiage-mixed-vegetable-tempura/kakiageingredients/
  FLAGGED [course-unverified-no-grounding]: kakiageingredients-recipetin-japan_japan_e1579c8a -- "sides"
  SKIP [empty-content]: kakiageingredients-recipetin-japan_japan_e1579c8a -- No ingredients or directions extracted
Extracting [138]: https://www.thebreadshebakes.com/2013/07/sourdough-bread-with-kamut-khorasan-flour/
  FLAGGED [not-searchable]: kamut-bread-recipe-khorasan-flour-the-bread-she-ba_thebreadshebakes_c2f3f66e -- "cuisine"
Extracting [139]: https://maunikagowardhan.co.uk/cook-in-a-curry/kandhari-murgh-tikka-chicken-with-spices-pomegranate-molasses/
  FLAGGED [course-unverified-no-grounding]: kandhari-murgh-tikka-indian-recipes-maunika-goward_maunikagowardhan_05ea34d1 -- "mains"
Extracting [140]: https://itdoesnttastelikechicken.com/kfc-coleslaw-copycat/
Extracting [141]: https://maunikagowardhan.co.uk/cook-in-a-curry/khajoor-pista-roll/
  FLAGGED [course-unverified-no-grounding]: khajoor-pista-roll-maunika-gowardhan_maunikagowardhan_15823b54 -- "sides"
Extracting [142]: https://maunikagowardhan.co.uk/cook-in-a-curry/khumb-matar-malai/
  FLAGGED [course-unverified-no-grounding]: khumb-matar-malai-maunika-gowardhan_maunikagowardhan_1ab1e95e -- "mains"
  FLAGGED [ingredient-placeholder-fabricated]: khumb-matar-malai-maunika-gowardhan_maunikagowardhan_1ab1e95e -- "Spice Powder Ingredients"
  FLAGGED [ingredient-name-embedded-amount]: khumb-matar-malai-maunika-gowardhan_maunikagowardhan_1ab1e95e -- "50mls Ml Soaking Liquid"
  FLAGGED [cuisine-from-site-fallback]: khumb-matar-malai-maunika-gowardhan_maunikagowardhan_1ab1e95e -- "IN"
Extracting [143]: https://modernistbread.com/kings-day-bread/
  SKIP [empty-content]: king-s-day-bread-modernist-bread_modernistbread_62ad1d40 -- No ingredients or directions extracted
Extracting [143]: https://mykoreankitchen.com/korean-mapo-tofu/
Extracting [144]: https://www.bongeats.com/recipe/kumrar-jhal
  FLAGGED [course-unverified-no-grounding]: kumro-r-jhaal-recipe-by-bong-eats_bongeats_7e559545 -- "mains"
Extracting [145]: https://www.theboywhobakes.co.uk/blog/2015/11/27/lemon-and-passion
  SKIP [empty-content]: lemon-and-passion-fruit-bundt-the-boy-who-bakes_theboywhobakes_abe23c0a -- No ingredients or directions extracted
Extracting [145]: https://annaolson.ca/project/liege-waffles/
  CUISINE-REVIEW: li-ge-waffles-anna-olson_annaolson_bf1323c4 -- site tagged "CA", recipe classified "BE"
Extracting [146]: https://www.meilleurduchef.com/en/recipe/lime-strawberry-tartlets.html
  FLAGGED [course-unverified-no-grounding]: lime-strawberry-tartlets_meilleurduchef_784d7fa0 -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  FLAGGED [cuisine-from-site-fallback]: lime-strawberry-tartlets_meilleurduchef_784d7fa0 -- "FR"
Extracting [147]: https://muybuenoblog.com/tamal-dough-masa-para-tamales/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 6 directions from a markdown Method/Instructions section after the model found none)
Extracting [148]: https://www.okonomikitchen.com/matcha-snowball-cookies/
  FLAGGED [course-unverified-no-grounding]: matcha-snowball-cookies-okonomi-kitchen_okonomikitchen_b2f83393 -- "sides"
  FLAGGED [compound-amount-detected]: matcha-snowball-cookies-okonomi-kitchen_okonomikitchen_b2f83393 -- "3 tbsp + 1 tsp (50 g) butter"
  FLAGGED [compound-amount-detected]: matcha-snowball-cookies-okonomi-kitchen_okonomikitchen_b2f83393 -- "3 tbsp + 1 tsp (25 g) almond flour"
Extracting [149]: https://www.diffordsguide.com/cocktails/recipe/6442/mediterranean-cooler
  FLAGGED [not-searchable]: mediterranean-cooler-cocktail-recipe_diffordsguide_de5d138a -- "cuisine"
Extracting [150]: https://www.diffordsguide.com/cocktails/recipe/40631/mediterranean-daiquiri
  SKIP [empty-content]: mediterranean-daiquiri-cocktail-recipe-master-bart_diffordsguide_6c999e2b -- No ingredients or directions extracted
Extracting [150]: https://www.diffordsguide.com/cocktails/recipe/2987/mediterranean-fizz
  FLAGGED [not-searchable]: mediterranean-fizz-cocktail-recipe_diffordsguide_b3dc3f6f -- "cuisine"
Extracting [151]: https://www.greatitalianchefs.com/recipes/mlinci-vegetables-recipe
  FLAGGED [cuisine-from-site-fallback]: mlinci-and-vegetables-recipe_greatitalianchefs_0158d42c -- "IT"
Extracting [152]: https://www.theperfectloaf.com/multigrain-spelt-sourdough/
  FLAGGED [not-searchable]: multigrain-spelt-sourdough-the-perfect-loaf_theperfectloaf_058b79f3 -- "cuisine"
Extracting [153]: https://lyres.com/en-uk/pages/negroni
  SKIP [empty-content]: negroni_lyres_f88c4854 -- No ingredients or directions extracted
Extracting [153]: https://insaneinthebrine.com/peach-onion-hotsauce/
  FLAGGED [no-directions-found]: nobody-calls-it-hotlanta-sauce-w-grilled-peach-vid_insaneinthebrine_24f988e6 -- "(whole recipe)"
  FLAGGED [cuisine-unverified-no-grounding]: nobody-calls-it-hotlanta-sauce-w-grilled-peach-vid_insaneinthebrine_24f988e6 -- "US"
Extracting [154]: https://lyres.com/en-uk/products/bittersweet-spritz-grande-duo-set-uk
  FLAGGED [cuisine-unverified-no-grounding]: non-alcoholic-bittersweet-spritz-cocktail-set-lyre_lyres_1db04e3a -- "IT"
  CUISINE-REVIEW: non-alcoholic-bittersweet-spritz-cocktail-set-lyre_lyres_1db04e3a -- cuisine "IT" has no grounding signal to verify against
Extracting [155]: https://lyres.com/en-uk/products/rosa-negroni-set-uk
  FLAGGED [not-searchable]: non-alcoholic-rosa-negroni-cocktail-set-lyre-s_lyres_a80f323a -- "cuisine"
Extracting [156]: https://khymos.org/2010/08/04/norwegian-egg-coffee/
  FLAGGED [cuisine-unverified-no-grounding]: norwegian-egg-coffee-khymos_khymos_efd5a3ca -- "NO"
  CUISINE-REVIEW: norwegian-egg-coffee-khymos_khymos_efd5a3ca -- cuisine "NO" has no grounding signal to verify against
Extracting [157]: https://modernistcuisine.com/recipes/olive-oil-gummy-worms/
  SKIP [empty-content]: olive-oil-gummy-worms-modernist-cuisine_modernistcuisine_b7f86c1c -- No ingredients or directions extracted
Extracting [157]: https://woonheng.com/osmanthus-konnyaku-jelly-balls/
  FLAGGED [ingredient-name-embedded-amount]: osmanthus-konnyaku-jelly-balls-woonheng_woonheng_a2e247bd -- "Water Up to 1.1l for a Softer Texture"
Extracting [158]: https://muybuenoblog.com/chimichuri-sauce/
  CUISINE-REVIEW: parsley-cilantro-chimichurri-sauce_muybuenoblog_2615d022 -- site tagged "MX", recipe classified "AR"
Extracting [159]: https://spanishsabores.com/patatas-alinadas-recipe-spanish-potato-salad/
Extracting [160]: https://www.greatbritishchefs.com/recipes/patatas-alinadas-with-cod-recipe
  (ldIngredientsRaw has 20 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
  FLAGGED [cuisine-from-site-fallback]: patatas-ali-adas-with-pan-fried-cod-recipe_greatbritishchefs_468169e1 -- "GB"
Extracting [161]: https://spanishsabores.com/patatas-alioli-recipe/
Extracting [162]: https://www.greatbritishchefs.com/recipes/patatas-bravas-recipe
  CUISINE-REVIEW: patatas-bravas-recipe_greatbritishchefs_963c21b6 -- site tagged "GB", recipe classified "ES"
Extracting [163]: https://barbecuebible.com/recipe/patatas-bravas-with-garlic-aioli/
  (recovered 5 directions from a markdown Method/Instructions section after the model found none)
  CUISINE-REVIEW: patatas-bravas-with-garlic-aioli_barbecuebible_8c87e6e4 -- site tagged "US", recipe classified "ES"
Extracting [164]: https://www.thestaffcanteen.com/chefs-recipes/patatas-bravas
  FLAGGED [ingredient-placeholder-fabricated]: patatas-bravas_thestaffcanteen_25021874 -- "Ingredients"
  FLAGGED [cuisine-unverified-no-grounding]: patatas-bravas_thestaffcanteen_25021874 -- "ES"
Extracting [165]: https://mykoreankitchen.com/patbingsu-korean-shaved-ice/
Extracting [166]: https://www.theboywhobakes.co.uk/recipes/2017/6/21/pear-and-raspberry-bakewell-brioche-buns
  FLAGGED [cuisine-from-site-fallback]: pear-and-raspberry-bakewell-brioche-buns-the-boy-w_theboywhobakes_8f289c80 -- "GB"
Extracting [167]: https://www.greatbritishchefs.com/recipes/pear-vanilla-jelly-recipe
  FLAGGED [course-unverified-no-grounding]: pear-and-vanilla-jelly-recipe_greatbritishchefs_198a270d -- "desserts"
  FLAGGED [cuisine-from-site-fallback]: pear-and-vanilla-jelly-recipe_greatbritishchefs_198a270d -- "GB"
Extracting [168]: https://www.thestaffcanteen.com/chefs-recipes/pear-blueberry-white-chocolate
  FLAGGED [not-searchable]: pear-blueberry-white-chocolate_thestaffcanteen_76b7e3ce -- "cuisine"
  SKIP [missing-meta]: perch-fillets-with-elderflowers_lacucinaitaliana_4f1854c8 -- No .meta.json found alongside .md file
Extracting [169]: https://barbecuebible.com/2019/10/11/perfect-barbecued-chicken/
Extracting [170]: https://annaolson.ca/project/pickled-hot-sweet-peppers/
  CUISINE-REVIEW: pickled-hot-sweet-peppers_annaolson_e8aa92e2 -- site tagged "CA", recipe classified "US"
Extracting [171]: https://barbecuebible.com/2005/01/20/pickled-peppers/
  SKIP [empty-content]: pickled-peppers_barbecuebible_552026c8 -- No ingredients or directions extracted
Extracting [171]: https://mykoreankitchen.com/pickled-radish-paper/
  FLAGGED [course-unverified-no-grounding]: pickled-radish-paper-ssam-mu_mykoreankitchen_247d6af2 -- "sides"
Extracting [172]: https://japan.recipetineats.com/sweet-and-sour-pickled-red-cabbage/pickled_red_cabbage_garnish_4993/
  FLAGGED [course-unverified-no-grounding]: pickled-red-cabbage-garnish-4993-recipetin-japan_japan_a39339ba -- "sides"
  SKIP [empty-content]: pickled-red-cabbage-garnish-4993-recipetin-japan_japan_a39339ba -- No ingredients or directions extracted
Extracting [172]: https://annaolson.ca/project/pineapple-raspberry-pavlova-with-lemon-curd/
  FLAGGED [cuisine-from-site-fallback]: pineapple-raspberry-pavlova-with-lemon-curd_annaolson_ea41ad2e -- "CA"
Extracting [173]: https://dailycookingquest.com/pisang-goreng-oat-fried-banana-oat.html
  FLAGGED [cuisine-unverified-no-grounding]: pisang-goreng-oat-fried-banana-oat_dailycookingquest_e6f7e7f2 -- "ID"
  CUISINE-REVIEW: pisang-goreng-oat-fried-banana-oat_dailycookingquest_e6f7e7f2 -- cuisine "ID" has no grounding signal to verify against
Extracting [174]: https://www.thebreadshebakes.com/2016/04/pissaladiere-recipe-french-flatbread/
  FLAGGED [cuisine-unverified-no-grounding]: pissaladi-re-ni-oise-flatbread-recipe-thebreadsheb_thebreadshebakes_749f0e20 -- "FR"
  CUISINE-REVIEW: pissaladi-re-ni-oise-flatbread-recipe-thebreadsheb_thebreadshebakes_749f0e20 -- cuisine "FR" has no grounding signal to verify against
Extracting [175]: https://thewoksoflife.com/pork-egg-foo-young/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 12 directions from a markdown Method/Instructions section after the model found none)
  CUISINE-REVIEW: pork-egg-foo-young_thewoksoflife_5773a765 -- site tagged "CN", recipe classified "US"
Extracting [176]: https://www.theboywhobakes.co.uk/recipes/2022/12/27/prune-tea-cakes
Extracting [177]: https://modernistcuisine.com/recipes/raspberry-sables-with-lemon-curd/
  SKIP [empty-content]: raspberry-sabl-s-with-lemon-curd-modernist-cuisine_modernistcuisine_4d1ebe7c -- No ingredients or directions extracted
Extracting [177]: https://www.thebreadshebakes.com/2014/08/baking-traditional-real-german-pumpernickel-bread/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [ingredient-name-embedded-amount]: real-german-pumpernickel-bread-recipe-the-bread-sh_thebreadshebakes_d5ba991a -- "Rye Sourdough Starter 350g Fine to Medium Cracked Rye; Rye Berries 200g Boiling Water; Fine to Medium Cracked Rye 150g Water"
  FLAGGED [no-directions-found]: real-german-pumpernickel-bread-recipe-the-bread-sh_thebreadshebakes_d5ba991a -- "(whole recipe)"
Extracting [178]: https://ottolenghi.co.uk/pages/recipes/roast-red-pepper-salad-anchovies-almonds
  FLAGGED [not-searchable]: roast-red-pepper-salad-with-anchovies-and-almonds-_ottolenghi_a94980de -- "cuisine"
Extracting [179]: https://www.thestaffcanteen.com/chefs-recipes/roasted-quail-butternut-squash-braised-red-cabbage-and-cinnamon-by-gary-jones
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [ingredient-name-embedded-amount]: roasted-quail-butternut-squash-braised-red-cabbage_thestaffcanteen_7de0df35 -- "1g Salt; 0.5g Ground Black Pepper; 0.5g Salt; 0.13g Ground Black Pepper"
  FLAGGED [no-directions-found]: roasted-quail-butternut-squash-braised-red-cabbage_thestaffcanteen_7de0df35 -- "(whole recipe)"
  FLAGGED [not-searchable]: roasted-quail-butternut-squash-braised-red-cabbage_thestaffcanteen_7de0df35 -- "cuisine"
Extracting [180]: https://ottolenghi.co.uk/pages/recipes/roman-fried-chicken-tomatoes-crisp-oregano
  FLAGGED [not-searchable]: roman-fried-chicken-with-tomato-and-crisp-oregano-_ottolenghi_42cd4454 -- "cuisine"
Extracting [181]: https://www.diffordsguide.com/cocktails/recipe/3536/roman-highball
  FLAGGED [not-searchable]: roman-highball-cocktail-recipe_diffordsguide_c4bb93d6 -- "cuisine"
Extracting [182]: https://modernistcuisine.com/recipes/sablee-brioche/
  SKIP [empty-content]: sabl-e-brioche-modernist-cuisine_modernistcuisine_d14e5ea0 -- No ingredients or directions extracted
Extracting [182]: https://mykoreankitchen.com/saeujeot/
  FLAGGED [course-unverified-no-grounding]: saeujeot-korean-salted-shrimp_mykoreankitchen_a1b06eef -- "sauces"
  SKIP [empty-content]: saeujeot-korean-salted-shrimp_mykoreankitchen_a1b06eef -- No ingredients or directions extracted
Extracting [182]: https://www.koreanbapsang.com/saewu-ganghwe-spring-onion-tied-shrimp/
  FLAGGED [course-unverified-no-grounding]: saewu-ganghwe-green-onion-tied-shrimp-and-asparagu_koreanbapsang_06faa510 -- "apps"
Extracting [183]: https://www.stadlermade.com/oven-recipes/salad/salad-on-fire/
  FLAGGED [cuisine-unverified-no-grounding]: salad-on-fire-stadler-made_stadlermade_01b08d13 -- "FR"
  CUISINE-REVIEW: salad-on-fire-stadler-made_stadlermade_01b08d13 -- cuisine "FR" has no grounding signal to verify against
Extracting [184]: https://www.theboywhobakes.co.uk/recipes/2021/4/7/salted-sesame-challah
  SKIP [empty-content]: salted-sesame-challah-the-boy-who-bakes_theboywhobakes_cc5665c2 -- No ingredients or directions extracted
Extracting [184]: https://www.seedlipdrinks.com/en-ca/recipes/seedlip-espresso-martini
  FLAGGED [not-searchable]: seedlip-espresso-martini-seedlip_seedlipdrinks_11f6393b -- "cuisine"
Extracting [185]: https://www.seedlipdrinks.com/en-us/recipes/garden-mojito
  FLAGGED [ingredient-name-embedded-amount]: seedlip-garden-mojito-repice-seedlip_seedlipdrinks_364fdaa8 -- "Simple Syrup: 1/2 Oz; Lime Juice: 3/4 Oz"
  (recovered 3 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [not-searchable]: seedlip-garden-mojito-repice-seedlip_seedlipdrinks_364fdaa8 -- "cuisine"
Extracting [186]: https://www.seedlipdrinks.com/en-aunz/recipes/seedlip-grove-spritz
  (recovered 3 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [not-searchable]: seedlip-grove-spritz-seedlip_seedlipdrinks_834b043e -- "cuisine"
Extracting [187]: https://www.seedlipdrinks.com/en-aunz/recipes/seedlip-margarita-grove
  (recovered 3 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [not-searchable]: seedlip-margarita-non-alcoholic-cocktails-seedlip-_seedlipdrinks_2d546a90 -- "cuisine"
Extracting [188]: https://www.seedlipdrinks.com/en-us/recipes/spiced-pumpkin-soda
  (recovered 4 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [not-searchable]: seedlip-spiced-pumpkin-soda-seedlip_seedlipdrinks_b9c3c95b -- "cuisine"
Extracting [189]: https://www.bongeats.com/recipe/shora-chitoi-pithe
  FLAGGED [course-unverified-no-grounding]: shora-or-chitoi-pithe-recipe-by-bong-eats_bongeats_da7b1aab -- "sides"
  (recovered 6 directions from a markdown Method/Instructions section after the model found none)
Extracting [190]: https://www.bongeats.com/recipe/shutki-mach-bata
  FLAGGED [course-unverified-no-grounding]: shutki-machh-bata-recipe-by-bong-eats_bongeats_4bbfea6f -- "mains"
  (recovered 14 directions from a markdown Method/Instructions section after the model found none)
Extracting [191]: https://itdoesnttastelikechicken.com/silken-tofu-chocolate-mousse/
Extracting [192]: https://modernistcuisine.com/recipes/silky-smooth-macaroni-and-cheese/
  SKIP [empty-content]: silky-smooth-macaroni-and-cheese-modernist-cuisine_modernistcuisine_23a6181a -- No ingredients or directions extracted
Extracting [192]: https://ladyandpups.com/2018/04/26/singapore-hawker-marathon-crystal-dumpling-zongzi-made-with-sago-pearls/
  FLAGGED [cuisine-unverified-no-grounding]: singapore-hawker-marathon-crystal-dumpling-zongzi-_ladyandpups_e225214d -- "CN"
  CUISINE-REVIEW: singapore-hawker-marathon-crystal-dumpling-zongzi-_ladyandpups_e225214d -- cuisine "CN" has no grounding signal to verify against
Extracting [193]: https://vickypham.com/blog/slow-cooker-mexican-pork-carnitas/
  CUISINE-REVIEW: slow-cooker-mexican-pork-carnitas-vicky-pham_vickypham_b17a74b9 -- site tagged "VN", recipe classified "MX"
Extracting [194]: https://amazingribs.com/tested-recipes/lamb-recipes/smoked-lamb-ribs-recipe/
Extracting [195]: https://www.stadlermade.com/oven-recipes/smokey-gratin/
  FLAGGED [not-searchable]: smokey-gratin-stadler-made_stadlermade_cd1af34f -- "cuisine"
Extracting [196]: https://ottolenghi.co.uk/products/smokey-sweet-marcona-almonds
  FLAGGED [no-directions-found]: smokey-sweet-marcona-almonds_ottolenghi_51938c07 -- "(whole recipe)"
  FLAGGED [cuisine-unverified-no-grounding]: smokey-sweet-marcona-almonds_ottolenghi_51938c07 -- "ES"
Extracting [197]: https://ottolenghi.co.uk/pages/recipes/smokey-sweetcorn-tofu-fritters
  FLAGGED [not-searchable]: smokey-sweetcorn-tofu-fritters-recipe-ottolenghi-r_ottolenghi_639207b2 -- "cuisine"
Extracting [198]: https://www.chinasichuanfood.com/snow-fungus-soup/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: snow-fungus-soup-with-asian-pears_chinasichuanfood_29e06c69 -- "(whole recipe)"
Extracting [199]: https://itdoesnttastelikechicken.com/soft-vegan-dinner-rolls/
Extracting [200]: https://blog.modernistpantry.com/recipes/some-like-it-hot-ice-cream/
  FLAGGED [not-searchable]: some-like-it-hot-ice-cream-kitchen-alchemy_blog_dd05446e -- "cuisine"
Extracting [201]: https://nomaprojects.com/products/some-like-it-hot
  FLAGGED [course-unverified-no-grounding]: some-like-it-hot_nomaprojects_7581b8b5 -- "sauces"
  FLAGGED [no-directions-found]: some-like-it-hot_nomaprojects_7581b8b5 -- "(whole recipe)"
  FLAGGED [cuisine-from-site-fallback]: some-like-it-hot_nomaprojects_7581b8b5 -- "DK"
Extracting [202]: https://www.chopstickchronicles.com/somen/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  (recovered 10 directions from a markdown Method/Instructions section after the model found none)
Extracting [203]: https://japan.recipetineats.com/somen-japanese-cold-noodles/
Extracting [204]: https://annaolson.ca/project/sour-cream-doughnut-holes/
  FLAGGED [cuisine-from-site-fallback]: sour-cream-doughnut-holes-anna-olson_annaolson_0d4dfa01 -- "CA"
Extracting [205]: https://ranveerbrar.com/user-recipes/sour-cream-potato-shells-by-madhav-sharma/
  FLAGGED [serves-looks-like-weight]: sour-cream-potato-shells-by-madhav-sharma-ranveer-_ranveerbrar_fe0d88c9 -- "120-150 gm"
  FLAGGED [cuisine-from-site-fallback]: sour-cream-potato-shells-by-madhav-sharma-ranveer-_ranveerbrar_fe0d88c9 -- "IN"
Extracting [206]: https://www.baking-sense.com/2017/03/01/sour-cream-pound-cake/
Extracting [207]: https://www.theperfectloaf.com/sourdough-90-rye-bread-recipe/
Extracting [208]: https://www.baking-sense.com/2020/12/20/sourdough-baba-au-rhum/
Extracting [209]: https://www.baking-sense.com/2025/11/29/sourdough-chocolate-babka/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: sourdough-babka_baking-sense_9a820984 -- "(whole recipe)"
Extracting [210]: https://www.baking-sense.com/2019/05/16/homemade-sourdough-bagels/
Extracting [211]: https://www.baking-sense.com/2019/08/01/sourdough-rye-bread/
Extracting [212]: https://www.theperfectloaf.com/sourdough-shokupan-japanese-milk-bread/
  FLAGGED [cuisine-unverified-no-grounding]: sourdough-shokupan-japanese-milk-bread-the-perfect_theperfectloaf_bfad0cb9 -- "JP"
  CUISINE-REVIEW: sourdough-shokupan-japanese-milk-bread-the-perfect_theperfectloaf_bfad0cb9 -- cuisine "JP" has no grounding signal to verify against
Extracting [213]: https://woonheng.com/spicy-cumin-lions-mane-mushrooms/
Extracting [214]: https://www.starchefs.com/recipes/aguachile-verde
  FLAGGED [cuisine-unverified-no-grounding]: starchefs-aguachile-verde-chef-carlos-raba-of-clav_starchefs_65f3d425 -- "MX"
  CUISINE-REVIEW: starchefs-aguachile-verde-chef-carlos-raba-of-clav_starchefs_65f3d425 -- cuisine "MX" has no grounding signal to verify against
Extracting [215]: https://www.starchefs.com/recipes/alaskeros-scallop-kinilaw
  FLAGGED [cuisine-unverified-no-grounding]: starchefs-alaskeros-scallop-kinilaw-aaron-verzosa-_starchefs_cd9e9418 -- "US"
  CUISINE-REVIEW: starchefs-alaskeros-scallop-kinilaw-aaron-verzosa-_starchefs_cd9e9418 -- cuisine "US" has no grounding signal to verify against
Extracting [216]: https://www.starchefs.com/recipes/black-eagle-gratzer
  FLAGGED [not-searchable]: starchefs-black-eagle-gratzer-reed-jaskula-of-plat_starchefs_1b429a12 -- "cuisine"
Extracting [217]: https://www.starchefs.com/recipes/black-eyed-pea-falafel
  FLAGGED [not-searchable]: starchefs-black-eyed-pea-falafel-chef-wes-scoggins_starchefs_d9188865 -- "cuisine"
Extracting [218]: https://www.starchefs.com/recipes/blackened-grouper-sandwich
  FLAGGED [ingredient-name-embedded-amount]: starchefs-blackened-grouper-sandwich-chef-bradford_starchefs_24a06620 -- "6-to-8 Ounce Grouper Fillets"
  FLAGGED [not-searchable]: starchefs-blackened-grouper-sandwich-chef-bradford_starchefs_24a06620 -- "cuisine"
Extracting [219]: https://www.starchefs.com/recipes/blackened-redfish
  SKIP [extract-error]: starchefs-blackened-redfish-chef-ryan-hacker-of-br_starchefs_657d1e57 -- fetch failed
Extracting [219]: https://www.starchefs.com/recipes/blackened-salmon-tostada
  FLAGGED [not-searchable]: starchefs-blackened-salmon-tostada-felipe-riccio-o_starchefs_239eaa22 -- "cuisine"
Extracting [220]: https://www.starchefs.com/recipes/blackened-scallops
  FLAGGED [not-searchable]: starchefs-blackened-scallops-nick-dlugoss-of-betts_starchefs_8d21df44 -- "cuisine"
Extracting [221]: https://www.greatbritishchefs.com/recipes/steak-tartare-recipe
  CUISINE-REVIEW: steak-tartare-recipe_greatbritishchefs_a75ad4ef -- site tagged "GB", recipe classified "FR"
Extracting [222]: https://www.lacucinaitaliana.com/recipe/appetizers/steak-tartare-with-dill-yogurt-sauce
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  (ldIngredientsRaw has 9 entries but none look like real ingredient lines (no amounts, all single words) -- falling back to whole-page extraction)
Extracting [223]: https://www.greatbritishchefs.com/recipes/steak-tartare-frites-recipe
  FLAGGED [cuisine-from-site-fallback]: steak-tartare-with-frites-recipe_greatbritishchefs_ae5c2a5d -- "GB"
Extracting [224]: https://www.greatbritishchefs.com/recipes/steak-tartare-rhubarb-recipe
  FLAGGED [cuisine-from-site-fallback]: steak-tartare-with-rhubarb-recipe_greatbritishchefs_48b5d7f8 -- "GB"
Extracting [225]: https://www.thestaffcanteen.com/chefs-recipes/steak-tartare-1764679944
  FLAGGED [not-searchable]: steak-tartare_thestaffcanteen_68a7cba8 -- "cuisine"
Extracting [226]: https://dailycookingquest.com/steak-tempe-tempeh-soy-bean-cake-steak.html
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [ingredient-name-embedded-amount]: steak-tempe-tempeh-soy-bean-cake-steak_dailycookingquest_c2ef8b2c -- "Corn Starch + 1 Tablespoon Water"
  (recovered 7 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-unverified-no-grounding]: steak-tempe-tempeh-soy-bean-cake-steak_dailycookingquest_c2ef8b2c -- "ID"
Extracting [227]: https://www.chinasichuanfood.com/steamed-fish-with-chili-sauce/
Extracting [228]: https://www.chinasichuanfood.com/steamed-tofu-with-chili-sauce/
Extracting [229]: https://www.theboywhobakes.co.uk/blog/2015/12/3/sticky-toffee-christmas-puddings
  FLAGGED [cuisine-from-site-fallback]: sticky-toffee-christmas-puddings-the-boy-who-bakes_theboywhobakes_e2495704 -- "GB"
Extracting [230]: https://omnivorescookbook.com/stir-fried-garlic-scape-with-eggs/
Extracting [231]: https://mykoreankitchen.com/gochujang-sauce/
  FLAGGED [course-unverified-no-grounding]: stir-fried-gochujang-sauce-yak-gochujang_mykoreankitchen_bccf7b03 -- "sides"
Extracting [232]: https://thewoksoflife.com/stir-fried-green-beans/
  FLAGGED [course-unverified-no-grounding]: stir-fried-green-beans-with-pork-and-chinese-olive_thewoksoflife_c13fc8bf -- "sides"
Extracting [233]: https://www.theperfectloaf.com/super-soft-sourdough-hot-cross-buns/
Extracting [234]: https://www.nyonyacooking.com/snaps/EdhKXgarS
  SKIP [empty-content]: sweet-and-sour-fish_nyonyacooking_fcfe2a4d -- No ingredients or directions extracted
Extracting [234]: https://maunikagowardhan.co.uk/cook-in-a-curry/tamil-pepper-chicken-curry/
  FLAGGED [course-unverified-no-grounding]: tamil-black-pepper-chicken-curry-maunika-gowardhan_maunikagowardhan_7c24148b -- "mains"
Extracting [235]: https://www.thebreadshebakes.com/2015/03/brazilian-tapioca-flour-buns/
  FLAGGED [cuisine-unverified-no-grounding]: tapioca-bread-brazilian-cheese-buns-the-bread-she-_thebreadshebakes_7afc9eb5 -- "BR"
  CUISINE-REVIEW: tapioca-bread-brazilian-cheese-buns-the-bread-she-_thebreadshebakes_7afc9eb5 -- cuisine "BR" has no grounding signal to verify against
Extracting [236]: https://japan.recipetineats.com/steamed-chicken-and-fish-with-vegetables/teo_dipping_sauces_5954/
  FLAGGED [course-unverified-no-grounding]: teo-dipping-sauces-5954-recipetin-japan_japan_3cd884fc -- "sauces"
  SKIP [empty-content]: teo-dipping-sauces-5954-recipetin-japan_japan_3cd884fc -- No ingredients or directions extracted
Extracting [236]: https://www.nyonyacooking.com/snaps/u_ICEhR8a
  FLAGGED [course-unverified-no-grounding]: teochew-steamed-fish_nyonyacooking_63231ed0 -- "mains"
  SKIP [empty-content]: teochew-steamed-fish_nyonyacooking_63231ed0 -- No ingredients or directions extracted
Extracting [236]: https://punchdrink.com/recipes/tepache-collins/
  FLAGGED [cuisine-unverified-no-grounding]: tepache-collins_punchdrink_aa3b2375 -- "MX"
  CUISINE-REVIEW: tepache-collins_punchdrink_aa3b2375 -- cuisine "MX" has no grounding signal to verify against
Extracting [237]: https://khymos.org/2012/09/16/tgrwt-22-round-up/
  FLAGGED [cuisine-unverified-no-grounding]: tgrwt-22-round-up-khymos_khymos_dd377e0d -- "JP"
  CUISINE-REVIEW: tgrwt-22-round-up-khymos_khymos_dd377e0d -- cuisine "JP" has no grounding signal to verify against
Extracting [238]: https://hot-thai-kitchen.com/kao-yum/
  FLAGGED [course-unverified-no-grounding]: thai-rainbow-rice-salad-khao-yum-is-a-southern-gem_hot-thai-kitchen_35c45b83 -- "salads"
Extracting [239]: https://www.madewithlau.com/recipes/popcorn-chicken
Extracting [240]: https://www.madewithlau.com/recipes/pork-knuckles-ginger-vinegar-stew
Extracting [241]: https://barbecuebible.com/recipe/the-port-hunters-hickory-grilled-clams-with-jalapenos-preserved-lemons/
  (recovered 5 directions from a markdown Method/Instructions section after the model found none)
Extracting [242]: https://www.madewithlau.com/recipes/potstickers
Extracting [243]: https://www.madewithlau.com/recipes/siu-mai
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: the-siu-mai-my-dad-s-made-100-000-times-made-with-_madewithlau_d474d481 -- "(whole recipe)"
Extracting [244]: https://lyres.com/en-me/products/lyres-london-dry-collins
  FLAGGED [no-directions-found]: tom-collins-mocktail-recipe-non-alcoholic-tom-coll_lyres_92a0569c -- "(whole recipe)"
  FLAGGED [not-searchable]: tom-collins-mocktail-recipe-non-alcoholic-tom-coll_lyres_92a0569c -- "cuisine"
Extracting [245]: https://www.baking-sense.com/2017/02/21/triple-guinness-bundt-cake/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: triple-guinness-bundt-cake_baking-sense_a76d1462 -- "(whole recipe)"
  FLAGGED [cuisine-unverified-no-grounding]: triple-guinness-bundt-cake_baking-sense_a76d1462 -- "IE"
Extracting [246]: https://barbecuebible.com/recipe/triple-smoked-potatoes/
  (recovered 8 directions from a markdown Method/Instructions section after the model found none)
  FLAGGED [cuisine-from-site-fallback]: triple-smoked-potatoes_barbecuebible_7777f254 -- "US"
Extracting [247]: https://www.meilleurduchef.com/en/recipe/ultimate-fraisier-strawberry-cake.html
  FLAGGED [course-unverified-no-grounding]: ultimate-fraisier-cake_meilleurduchef_85627277 -- "desserts"
  (htmlIngredientLines matched a site config but doesn't look like real ingredient lines (no amounts, mostly single words) -- likely matched the wrong element on the page, falling back)
  FLAGGED [cuisine-from-site-fallback]: ultimate-fraisier-cake_meilleurduchef_85627277 -- "FR"
Extracting [248]: https://joepastry.com/2015/upside-down-cake-recipe/#comments
  FLAGGED [not-searchable]: upside-down-cake-recipe-joe-pastry_joepastry_8d6b8833 -- "cuisine"
Extracting [249]: https://itdoesnttastelikechicken.com/vegan-butternut-squash-mac-and-cheese/
Extracting [250]: https://itdoesnttastelikechicken.com/vegan-gingerbread-cake/
Extracting [251]: https://www.greatitalianchefs.com/recipes/vegan-panzanella-salad-recipe
  FLAGGED [adapted-dish-cuisine-unresolved]: vegan-panzanella-salad-recipe_greatitalianchefs_20eaeaa4 -- "Vegan Panzanella Salad"
  FLAGGED [not-searchable]: vegan-panzanella-salad-recipe_greatitalianchefs_20eaeaa4 -- "cuisine"
Extracting [252]: https://woonheng.com/vegan-salmon-bowl/
  FLAGGED [ingredient-name-embedded-amount]: vegan-salmon-bowl-made-from-tofu-woonheng_woonheng_7e45e519 -- "Hot Water Mix with 1 Teaspoon Kelp Powder"
Extracting [253]: https://woonheng.com/vegan-zucchini-pocket-pie/
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [ingredient-name-embedded-amount]: vegan-zucchini-pocket-pie-woonheng_woonheng_6baa1e8a -- "Vermicelli 50g Optional"
Extracting [254]: https://vickypham.com/blog/vietnamese-chicken-noodle-soup-pho-ga/
  FLAGGED [ingredient-name-embedded-amount]: vietnamese-chicken-noodle-soup-ph-g-vicky-pham_vickypham_1eee96d2 -- "Packages 16-oz Fresh Rice Noodles"
Extracting [255]: https://vickypham.com/blog/vietnamese-pandan-waffles-banh-kep-la-dua/
  FLAGGED [ingredient-name-embedded-amount]: vietnamese-coconut-pandan-waffles-banh-kep-la-dua-_vickypham_aee594f1 -- "Vegetable Oil Plus Additional 1 Tablespoon for Greasing Waffle Iron"
Extracting [256]: https://vickypham.com/blog/vietnamese-steamed-pork-buns/
Extracting [257]: https://spanishsabores.com/watermelon-sangria-recipe/
  FLAGGED [ingredient-name-embedded-amount]: watermelon-sangria-recipe-spanish-sabores_spanishsabores_bedb7a36 -- "1.8 Kg Watermelon; 750 Ml Bottle of Dry Unoaked White Wine"
Extracting [258]: https://annaolson.ca/project/whipped-cream-frosting/
  FLAGGED [cuisine-from-site-fallback]: whipped-cream-frosting-anna-olson_annaolson_3797d4fb -- "CA"
Extracting [259]: https://bakefromscratch.com/white-sandwich-bread/
  FLAGGED [not-searchable]: white-sandwich-bread-bake-from-scratch_bakefromscratch_f2def0c6 -- "cuisine"
Extracting [260]: https://thewoksoflife.com/wonton-egg-drop-soup/
  CUISINE-REVIEW: wonton-egg-drop-soup_thewoksoflife_3179b2c6 -- site tagged "CN", recipe classified "US"
Extracting [261]: https://www.nyonyacooking.com/snaps/Guc7MjIsJL
  FLAGGED [course-unverified-no-grounding]: wonton-noodles_nyonyacooking_4fa5f661 -- "mains"
  SKIP [empty-content]: wonton-noodles_nyonyacooking_4fa5f661 -- No ingredients or directions extracted
Extracting [261]: https://www.the-bread-code.io/recipe/2021/12/17/sourdough-stollen.html
Extracting [262]: https://hot-thai-kitchen.com/yen-ta-fo/
  FLAGGED [course-unverified-no-grounding]: yen-ta-fo-pink-noodle-soup_hot-thai-kitchen_4f410a86 -- "soups"
  (ldInstructionsRaw present but doesn't look like real steps -- keeping whole-page directions)
  FLAGGED [no-directions-found]: yen-ta-fo-pink-noodle-soup_hot-thai-kitchen_4f410a86 -- "(whole recipe)"
Extracting [263]: https://www.koreanbapsang.com/yukjeon-pan-fried-battered-beef/
  FLAGGED [course-unverified-no-grounding]: yukjeon-pan-fried-battered-beef_koreanbapsang_402d64bb -- "mains"
Extracting [264]: https://ottolenghi.co.uk/pages/recipes/yuzu-dressed-slaw-fried-peanuts-thai-basil
  FLAGGED [not-searchable]: yuzu-dressed-slaw-fried-peanuts-and-thai-basil-ott_ottolenghi_88050535 -- "cuisine"
Extracting [265]: https://www.chopstickchronicles.com/yuzu-fruits/
  FLAGGED [course-unverified-no-grounding]: yuzu-fruits-chopstick-chronicles_chopstickchronicles_4636f630 -- "sides"
  SKIP [empty-content]: yuzu-fruits-chopstick-chronicles_chopstickchronicles_4636f630 -- No ingredients or directions extracted
Extracting [265]: https://www.davidlebovitz.com/a-bit-of-a-pick/
  CUISINE-REVIEW: zuni-s-pickled-red-onion-recipe-david-lebovitz_davidlebovitz_5d9e9914 -- site tagged "FR", recipe classified "US"
Extracting [266]: https://www.lacucinaitaliana.com/recipe/cakes-and-desserts/zuppa-inglese-traditional-italian-trifle
  FLAGGED [course-unverified-no-grounding]: zuppa-inglese-traditional-italian-trifle_lacucinaitaliana_9fc1dfa7 -- "desserts"
Extracting [267]: https://www.thebreadshebakes.com/2016/11/zwieback-crackers-recipe/
  FLAGGED [cuisine-unverified-no-grounding]: zwieback-crackers-recipe-the-bread-she-bakes_thebreadshebakes_9f99a409 -- "DE"
  CUISINE-REVIEW: zwieback-crackers-recipe-the-bread-she-bakes_thebreadshebakes_9f99a409 -- cuisine "DE" has no grounding signal to verify against

Done. Extracted: 267 (clean: 99, needs-review: 127, cuisine-review: 41), already had: 0, failed: 36
Failures logged to logs-test/extract-errors.jsonl
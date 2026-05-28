CREATE OR REPLACE FUNCTION search_walkin_sql_filter(
  p_query text DEFAULT NULL,
  p_cuisine text[] DEFAULT NULL,
  p_region text DEFAULT NULL,
  p_course text DEFAULT NULL,
  p_ingredient text DEFAULT NULL,
  p_max_time_minutes int DEFAULT NULL,
  p_wants_untried bool DEFAULT FALSE,
  p_match_count int DEFAULT 20,
  p_preferred_courses text[] DEFAULT NULL,
  p_prefers_long_project bool DEFAULT FALSE,
  p_exclude_cuisine text DEFAULT NULL
)
RETURNS TABLE (
  name text,
  course_label text,
  cuisine text,
  region text,
  "time" text,
  ingredient_names text[],
  domain_type text,
  technique text,
  difficulty text,
  tags text[],
  is_favourite bool,
  cook_count int,
  rating int,
  similarity_score float
)
LANGUAGE sql
STABLE
AS $$
  WITH candidates AS (
    SELECT
      rt.payload->'recipe'->>'name'                     AS name,
      rt.payload->'recipe'->>'course'                   AS course_label,
      rt.payload->'recipe'->>'cuisine'                  AS cuisine,
      rt.payload->'recipe'->>'region'                   AS region,
      rt.payload->'recipe'->>'time'                     AS time,
      ARRAY(
        SELECT jsonb_array_elements_text(
          rt.payload->'recipe'->'ingredients'
        )
      )                                                  AS ingredient_names,
      rt.domain_type                                     AS domain_type,
      rt.payload->'recipe'->>'technique'                AS technique,
      rt.payload->'recipe'->>'difficulty'               AS difficulty,
      ARRAY(
        SELECT jsonb_array_elements_text(
          rt.payload->'recipe'->'tags'
        )
      )                                                  AS tags,
      COALESCE(
        (rt.payload->'recipe'->>'isFavourite')::bool, false
      )                                                  AS is_favourite,
      COALESCE(
        (rt.payload->'recipe'->>'cookCount')::int, 0
      )                                                  AS cook_count,
      COALESCE(
        (rt.payload->'recipe'->>'rating')::int, 0
      )                                                  AS rating,
      (
        LEAST(
          COALESCE((rt.payload->'recipe'->>'cookCount')::int, 0), 10
        ) * 1.0
        + COALESCE(
            (rt.payload->'recipe'->>'isFavourite')::bool::int, 0
          ) * 3.0
        + LEAST(
            COALESCE((rt.payload->'recipe'->>'rating')::int, 0), 5
          ) * 0.5
        + CASE
            WHEN p_preferred_courses IS NOT NULL
                 AND array_length(p_preferred_courses, 1) > 0
                 AND EXISTS (
                   SELECT 1
                   FROM unnest(p_preferred_courses) pc
                   WHERE lower(pc) = lower(rt.payload->'recipe'->>'course')
                 )
            THEN 2.0
            ELSE 0.0
          END
      )                                                  AS similarity_score

    FROM memoix.rag_telemetry rt

    WHERE

      -- Cuisine filter: matches against any value in the array
      (
        p_cuisine IS NULL
        OR array_length(p_cuisine, 1) = 0
        OR upper(rt.payload->'recipe'->>'cuisine') = ANY(
             SELECT upper(c) FROM unnest(p_cuisine) c
           )
      )

      -- Region filter: partial match to handle 'Oaxacan', 'Bordeaux' etc
      AND (
        p_region IS NULL
        OR lower(rt.payload->'recipe'->>'region') 
           ILIKE '%' || lower(p_region) || '%'
      )

      -- Course filter
      AND (
        p_course IS NULL
        OR lower(rt.payload->'recipe'->>'course') = lower(p_course)
      )

      -- Ingredient filter: match against ingredient name array in payload
      AND (
        p_ingredient IS NULL
        OR EXISTS (
          SELECT 1
          FROM jsonb_array_elements(
            rt.payload->'recipe'->'ingredients'
          ) ing
          WHERE lower(ing->>'name')
            ILIKE '%' || lower(p_ingredient) || '%'
        )
      )

      -- "time" filter: parse "time" string and compare to max minutes
      AND (
        p_max_time_minutes IS NULL
        OR (
          rt.payload->'recipe'->>'time' IS NULL
          OR (
            COALESCE(
              (regexp_match(
                rt.payload->'recipe'->>'time', '(\d+)\s*h'
              ))[1]::int * 60, 0
            )
            +
            COALESCE(
              (regexp_match(
                rt.payload->'recipe'->>'time', '(\d+)\s*m'
              ))[1]::int, 0
            )
          ) <= p_max_time_minutes
        )
      )

      -- Untried filter: only recipes with zero cook count
      AND (
        NOT p_wants_untried
        OR COALESCE(
             (rt.payload->'recipe'->>'cookCount')::int, 0
           ) = 0
      )

      -- Text filter: applied only when p_query is provided and no
      -- structured filters are present, as a catch-all
      AND (
        p_query IS NULL
        OR p_cuisine IS NOT NULL
        OR p_region IS NOT NULL
        OR p_course IS NOT NULL
        OR p_ingredient IS NOT NULL
        OR lower(rt.payload->'recipe'->>'name')
             ILIKE '%' || lower(p_query) || '%'
        OR lower(rt.payload->'recipe'->>'cuisine')
             ILIKE '%' || lower(p_query) || '%'
      )

      -- Long-project filter
      AND (
        NOT p_prefers_long_project
        OR COALESCE(
             jsonb_array_length(rt.payload->'recipe'->'directions'), 0
           ) >= 6
        OR (
          COALESCE(
            (regexp_match(
              rt.payload->'recipe'->>'time', '(\d+)\s*h'
            ))[1]::int * 60, 0
          )
          +
          COALESCE(
            (regexp_match(
              rt.payload->'recipe'->>'time', '(\d+)\s*m'
            ))[1]::int, 0
          )
        ) >= 90
        OR (
          rt.domain_type = 'smoking'
          AND (
            COALESCE(
              (regexp_match(
                rt.payload->'recipe'->>'time', '(\d+)\s*h'
              ))[1]::int * 60, 0
            )
            +
            COALESCE(
              (regexp_match(
                rt.payload->'recipe'->>'time', '(\d+)\s*m'
              ))[1]::int, 0
            )
          ) >= 30
        )
      )

      -- Cuisine exclusion
      AND (
        p_exclude_cuisine IS NULL
        OR trim(p_exclude_cuisine) = ''
        OR upper(rt.payload->'recipe'->>'cuisine') != upper(p_exclude_cuisine)
      )
  )

  SELECT
    name, course_label, cuisine, region, "time",
    ingredient_names, domain_type, technique, difficulty,
    tags, is_favourite, cook_count, rating, similarity_score
  FROM candidates
  ORDER BY similarity_score DESC
  LIMIT p_match_count
$$;
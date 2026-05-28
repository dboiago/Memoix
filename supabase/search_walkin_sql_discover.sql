CREATE OR REPLACE FUNCTION search_walkin_sql_discover(
  p_match_count int DEFAULT 20
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
  SELECT
    rt.payload->'recipe'->>'name'                     AS name,
    rt.payload->'recipe'->>'course'                   AS course_label,
    rt.payload->'recipe'->>'cuisine'                  AS cuisine,
    rt.payload->'recipe'->>'region'                   AS region,
    rt.payload->'recipe'->>'time'                     AS "time",
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
    )                                                  AS similarity_score

  FROM memoix.rag_telemetry rt

  ORDER BY similarity_score DESC, random()
  LIMIT p_match_count
$$;
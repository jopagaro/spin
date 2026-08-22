# My Realm art pipeline

`masters/` contains the full-resolution generated source artwork. The app consumes
optimized copies installed into the iOS asset catalog. The world is composited from
one background plus one transparent sprite per rank unlock; locked previews reuse
the same sprite with a grayscale/dark shader rather than separate silhouette art.

## Peasantry contract (ranks 1–10)

- Fixed orthographic isometric camera, approximately 35 degrees.
- Warm light from the upper left; shadows fall lower right.
- Transparent alpha around every unlock sprite.
- No text or UI baked into art.
- Only Rank 9, Turnip Knight, may contain turnip imagery.
- Rank 10 replaces the Rank 1 hut; other ranks add a new layer.

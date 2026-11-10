# Evidencia de SQLite en DB Browser

La base de demostracion `pronuncia-demo.db` contiene solo datos sinteticos.
Incluye intentos de tarjetas, voz, dedos y poses, además de un tema sin
intentos para comprobar que el `LEFT JOIN` conserva temas vacios.

## Regenerar la base

Desde la raiz del proyecto, ejecuta una sola vez:

```powershell
dart run tool/crear_bd_demo.dart
```

El comando no sobrescribe una base existente. Para regenerarla, mueve o
renombra primero `pronuncia-demo.db`, o indica otra ruta:

```powershell
dart run tool/crear_bd_demo.dart evidencias/db-browser/pronuncia-demo-nueva.db
```

## Revisar en DB Browser for SQLite

1. Abre `evidencias/db-browser/pronuncia-demo.db`.
2. En **Browse Data**, revisa las tablas `temas`, `palabras` e `intentos`.
3. En **Execute SQL**, ejecuta las consultas siguientes y captura la ventana
   con la base y los resultados visibles para adjuntarla a la memoria.

### Aciertos por tema

```sql
SELECT
  t.nombre AS tema,
  COUNT(i.id) AS total_intentos,
  COALESCE(SUM(CASE WHEN i.acierto = 1 THEN 1 ELSE 0 END), 0) AS aciertos,
  CASE
    WHEN COUNT(i.id) = 0 THEN 0
    ELSE ROUND(
      100.0 * SUM(CASE WHEN i.acierto = 1 THEN 1 ELSE 0 END) / COUNT(i.id)
    )
  END AS porcentaje_acierto
FROM temas t
LEFT JOIN palabras p ON p.tema_id = t.id
LEFT JOIN intentos i ON i.palabra_id = p.id
GROUP BY t.id, t.nombre
ORDER BY t.nombre;
```

### Palabras con más fallos

```sql
SELECT
  p.ingles,
  p.espanol,
  COUNT(i.id) AS fallos
FROM palabras p
INNER JOIN intentos i ON i.palabra_id = p.id
WHERE i.acierto = 0
GROUP BY p.id, p.ingles, p.espanol
ORDER BY fallos DESC, p.ingles COLLATE NOCASE
LIMIT 5;
```

La aplicacion ejecuta las consultas equivalentes desde
`lib/data/intento_repository.dart`; sus resultados se muestran en la pantalla
de Estadisticas.

## Evidencias y modelo ER

- `CapturaBD1.png`: consulta de aciertos por tema.
- `CapturaBD2.png`: consulta de palabras con más fallos.
- `esquema-er.svg`: tablas, atributos, claves y cardinalidades de la base.

El diagrama corresponde al esquema creado por
`lib/data/database_helper.dart`. Las relaciones de temas a palabras y de
palabras a intentos son 1:N; ambas claves foráneas tienen borrado en cascada.

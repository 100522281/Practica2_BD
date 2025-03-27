WITH language_dividido AS (
    SELECT e.TITLE, e.AUTHOR, e.ISBN,
        SUBSTR(e.LANGUAGE, 1, 3) AS lang1, -- meto en lang1 los 3 primeros caracteres de LANGUAGE
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 3 THEN SUBSTR(e.ALT_LANGUAGES, 1, 3) -- los 3 primeros caracteres de ALT_LANGUAGES
            ELSE NULL
        END AS lang2,
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 6 THEN SUBSTR(e.ALT_LANGUAGES, 4, 3) -- los 3 siguientes caracteres de ALT_LANGUAGES
            ELSE NULL
        END AS lang3,
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 9 THEN SUBSTR(e.ALT_LANGUAGES, 7, 3) ---- los 3 siguientes caracteres de ALT_LANGUAGES
            ELSE NULL
        END AS lang4
    FROM Editions e
),
LanguagesPorEdition AS (

    SELECT TITLE, AUTHOR, ISBN, lang1 AS language FROM language_dividido WHERE lang1 IS NOT NULL UNION
    SELECT TITLE, AUTHOR, ISBN, lang2 FROM language_dividido WHERE lang2 IS NOT NULL UNION
    SELECT TITLE, AUTHOR, ISBN, lang3 FROM language_dividido WHERE lang3 IS NOT NULL UNION
    SELECT TITLE, AUTHOR, ISBN, lang4 FROM language_dividido WHERE lang4 IS NOT NULL
),
languages_contador AS (
    -- Contar idiomas distintos por libro (TITLE, AUTHOR)
    SELECT TITLE, AUTHOR, COUNT(DISTINCT language) AS language_count
    FROM languages_por_edicion GROUP BY TITLE, AUTHOR HAVING COUNT(DISTINCT language) >= 3
),

libros_no_prestados AS (
    -- Identificar libros cuyas copias nunca han sido prestadas
    SELECT 
        e.TITLE, e.AUTHOR FROM Editions e
    LEFT JOIN Copies c ON e.ISBN = c.ISBN
    LEFT JOIN Loans l ON c.SIGNATURE = l.SIGNATURE
    GROUP BY e.TITLE, e.AUTHOR HAVING COUNT(l.SIGNATURE) = 0
)


-- Seleccionar libros con al menos 3 idiomas y sin préstamos
SELECT 
    lc.TITLE, lc.AUTHOR, lc.language_count FROM languages_contador lc
    JOIN libros_no_prestados lnp ON lc.TITLE = lnp.TITLE AND lc.AUTHOR = lnp.AUTHOR ORDER BY lc.TITLE, lc.AUTHOR;
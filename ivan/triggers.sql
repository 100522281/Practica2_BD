-- Código SQL para crear los triggers de la base de datos

-- Trigger para Añadir una columna "número de lecturas" (lecturas) a la tabla ‘Libros’. Cuando
-- se presta un libro, se actualizará el número de lecturas
 CREATE OR REPLACE TRIGGER update_n_reads
AFTER INSERT ON LOANS
FOR EACH ROW

DECLARE 
    v_isbn   COPIES.ISBN%TYPE;
    v_title  EDITIONS.TITLE%TYPE;
    v_author EDITIONS.AUTHOR%TYPE;

BEGIN
    -- Obtener el ISBN desde COPIES
    BEGIN
        SELECT ISBN INTO v_isbn 
        FROM COPIES 
        WHERE SIGNATURE = :NEW.SIGNATURE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Si no se encuentra la firma, termina el trigger sin hacer nada
            RETURN;
    END;

    -- Obtener el título y autor desde EDITIONS
    BEGIN
        SELECT TITLE, AUTHOR INTO v_title, v_author
        FROM EDITIONS
        WHERE ISBN = v_isbn;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Si no se encuentra la edición, termina el trigger sin hacer nada
            RETURN;
    END;

    -- Actualizar el número de lecturas en BOOKS
    UPDATE BOOKS
    SET N_READS = NVL(N_READS, 0) + 1
    WHERE TITLE = v_title
      AND AUTHOR = v_author;

END;
/

-- Trigger para Evitar los "posts" de usuarios institucionales (bibliotecas municipales)

CREATE OR REPLACE TRIGGER prevent_institutional_posts
BEFORE INSERT ON posts
FOR EACH ROW
DECLARE
    v_user_type CHAR(1);
BEGIN
    -- Obtener el tipo de usuario asociado al USER_ID del nuevo post
    SELECT TYPE INTO v_user_type
    FROM users
    WHERE USER_ID = :NEW.USER_ID;
    
    -- Verificar si el usuario es institucional (biblioteca municipal)
    IF v_user_type = 'L' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Los usuarios institucionales (bibliotecas municipales) no pueden realizar publicaciones.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si el USER_ID no existe en la tabla users, lanzar un error
        RAISE_APPLICATION_ERROR(-20002, 'El usuario especificado no existe en la base de datos.');
END;
/
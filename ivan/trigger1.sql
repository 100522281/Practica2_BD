
-- Añadir columna LECTURAS a la tabla BOOKS
ALTER TABLE BOOKS ADD (LECTURAS NUMBER DEFAULT 0);

-- Trigger 
-- Trigger para Añadir una columna "número de lecturas" (lecturas) a la tabla ‘Libros’. Cuando
-- se presta un libro, se actualizará el número de lecturas
CREATE OR REPLACE TRIGGER update_lecturas
AFTER INSERT ON LOANS
FOR EACH ROW
DECLARE 
    v_title  VARCHAR2(255); 
    v_author VARCHAR2(255); 
BEGIN
    -- Obtener el título y autor del libro prestado desde la tabla COPIES
    BEGIN
        SELECT e.TITLE, e.AUTHOR
        INTO v_title, v_author
        FROM COPIES c
        JOIN EDITIONS e ON c.ISBN = e.ISBN
        WHERE c.SIGNATURE = :NEW.SIGNATURE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN; -- Salir si no se encuentra la copia o la edición
    END;

    -- Incrementar el número de lecturas en la tabla BOOKS
    UPDATE BOOKS
    SET LECTURAS = NVL(LECTURAS, 0) + 1
    WHERE TITLE = v_title
      AND AUTHOR = v_author;
END;
/


-- TESTS 1

-- Consultas para saber que datos vamos a utilizar
select user_id from loans where rownum <= 4;

select signature from loans where user_id = '9994309633';

select * from loans where user_id = '9994309633' and signature = 'NA009';
-- SIGNA = NA009  USER_ID = 9994309633  STOPDATE = 23-NOV-24
-- TOWN = Valvacas  PROVINCE = Cádiz  T = L    TIME = 680 
-- RETURN  = 07-DEC-24


select isbn from copies where signature = 'NA009';

select title,author from editions where isbn = '84-85707-12-5';

select * from books where title = 'Cuentos de fin de aÃ±o' and author = 'GÃ³mez de la Serna, RamÃ³n, ( 1888-1963)';



-- Deleteamos posts
DELETE FROM posts;


-- PRUEBA 1. Eliminamos la insercion de loans, la volvemos a insertar y vemos si ha cambiado lecturas
--
-- Vemos lecturas en el libro de la prueba (deberia ser un cero)
SELECT lecturas FROM books  where title = 'Cuentos de fin de aÃ±o' and author = 'GÃ³mez de la Serna, RamÃ³n, ( 1888-1963)';
--
-- Eliminamos la fila de loans relacionada con la prueba 
DELETE FROM loans where user_id = '9994309633' and signature = 'NA009';
--
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME, RETURN)
VALUES ('NA009', '9994309633', TO_DATE('2024-11-23', 'YYYY-MM-DD'),'Valvacas', 'Cádiz', 'L', 680, TO_DATE('2024-12-07', 'YYYY-MM-DD'));
--
-- Consultamos de nuevo el libro (deberia salir un 1)
SELECT lecturas FROM books  where title = 'Cuentos de fin de aÃ±o' and author = 'GÃ³mez de la Serna, RamÃ³n, ( 1888-1963)';



-- PRUEBA 2. Insercion de un prestamo no valido para ver que no actualiza el valor cuando no debe
--
-- Vemos lecturas en el libro de la prueba para ver que valor tiene
SELECT lecturas FROM books  where title = 'Cuentos de fin de aÃ±o' and author = 'GÃ³mez de la Serna, RamÃ³n, ( 1888-1963)';
--
-- Eliminamos la fila de loans relacionada con la prueba 
DELETE FROM loans where user_id = '9994309633' and signature = 'NA009';
-- 
-- Insertamos un loan no valido (no deberia realizarse la insercion)
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME, RETURN)
VALUES ('c930a', '9994309633', TO_DATE('2024-11-23', 'YYYY-MM-DD'),'Valvacas', 'Cádiz', 'L', 680, TO_DATE('2024-12-07', 'YYYY-MM-DD'));
--
-- Consultamos de nuevo el libro (deberia salir el mismo numero)
SELECT lecturas FROM books  where title = 'Cuentos de fin de aÃ±o' and author = 'GÃ³mez de la Serna, RamÃ³n, ( 1888-1963)';


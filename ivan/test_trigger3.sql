
-- Prueba trigger 3


-- Insertar datos de prueba
INSERT INTO Copies (SIGNATURE, ISBN, CONDITION, DEREGISTERED)
VALUES ('C0001', '978-84-220-1887-2', 'G', NULL);

INSERT INTO Copies (SIGNATURE, ISBN, CONDITION, DEREGISTERED)
VALUES ('C0002', '978-84-220-1887-2', 'G', NULL);

COMMIT;

-- Verificar estado inicial
SELECT SIGNATURE, CONDITION, DEREGISTERED FROM Copies WHERE SIGNATURE IN ('C0001', 'C0002');



-- Prueba 1: Cambiar CONDITION a 'D' y verificar DEREGISTERED
UPDATE Copies SET CONDITION = 'D' WHERE SIGNATURE = 'C0001';

-- Verificar resultado
SELECT SIGNATURE, CONDITION, DEREGISTERED FROM Copies WHERE SIGNATURE = 'C0001';
--Resultado esperado: 'C0001' con CONDITION = 'D' y DEREGISTERED con fecha y hora actuales.



-- Prueba 2: Actualizar CONDITION a 'D' cuando ya es 'D'
UPDATE Copies SET CONDITION = 'D' WHERE SIGNATURE = 'C0001';

-- Verificar resultado
SELECT SIGNATURE, CONDITION, DEREGISTERED FROM Copies WHERE SIGNATURE = 'C0001';
-- Resultado esperado: 'C0001' con CONDITION = 'D' y DEREGISTERED sin cambios (no se actualiza).



-- Prueba 3: Cambiar CONDITION a 'W' y verificar que DEREGISTERED no se actualiza
UPDATE Copies SET CONDITION = 'W' WHERE SIGNATURE = 'C0001';

-- Verificar resultado
SELECT SIGNATURE, CONDITION, DEREGISTERED FROM Copies WHERE SIGNATURE = 'C0001';
-- Resultado esperado: 'C0001' con CONDITION = 'W' y DEREGISTERED sin cambios (no se actualiza).



-- Prueba 4: Actualizar otra columna sin cambiar CONDITION
UPDATE Copies SET COMMENTS = 'Prueba' WHERE SIGNATURE = 'C0002';

-- Verificar resultado
SELECT SIGNATURE, CONDITION, DEREGISTERED FROM Copies WHERE SIGNATURE = 'C0002';
-- Resultado esperado: 'C0002' con CONDITION = 'G' y DEREGISTERED sin cambios (no se actualiza).





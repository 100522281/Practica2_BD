-- función

create or replace function my_func(premio varchar2) return varchar2 is

	aux varchar2 (100) ; -- declaración de variables

begin
	select awards into aux from books where awards = premio;
	return aux;

exception --entre cada begin y end puedo tener un bloque de excepciones
	when no_data_found then dbms_output.put_line('No hay datos');return 'error';
	when too_many_rows then dbms_output.put_line('demasiadas filas');return 'error';
	when others then dbms_output.put_line('ERROR'); return 'error';
end;
/


-- para comprobar que la funcion devuelve el valor correcto:
declare dep varchar2(200);
begin
	dep := my_func('Premio Espasa de ensayo, 2010');
	dbms_output.put_line(dep);
end;
/
select position, constraint_name, column_name
from user_cons_columns cc
where exists
  (select 1 from user_constraints c
   where c.constraint_type = 'R'
     and c.table_name = cc.table_name
     and c.constraint_name = cc.constraint_name)
and not exists
  (select 1 from user_ind_columns i
   where i.table_name = cc.table_name
     and i.column_name = cc.column_name
     and i.column_position = cc.position)
order by table_name, constraint_name;

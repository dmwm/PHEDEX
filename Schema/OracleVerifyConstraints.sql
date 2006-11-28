select position, table_name, column_name from
 (select t1.table_name, t1.column_name, t1.position, t2.index_name ind_name
  from (select constraint_name, table_name, column_name, position
        from user_cons_columns where (table_name, constraint_name) in
          (select table_name, constraint_name from user_constraints
           where constraint_type = 'R')
        order by table_name, constraint_Name, position) t1,
       (select index_name, table_name, column_name, column_position
        from all_ind_columns
        order by table_name, index_name, column_position) t2
  where t1.table_name = t2.table_name(+)
    and t1.column_name = t2.column_name(+)
    and t1.position = t2.column_position(+)
  order by t1.table_name, t1.column_name)
where ind_name is null;

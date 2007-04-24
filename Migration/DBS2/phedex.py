import cx_Oracle

class PhedexApi:
    def __init__(self, connect):
        self.connect(connect)

    def connect(self, connect):
        self.con = cx_Oracle.connect(connect)
        return self.con

    def getBlocks(self, dataset=None):
        if not dataset: return []
        
        sql = ''' select b.name
                    from t_dps_dataset ds
                         join xt_dps_block b on b.dataset = ds.id
                   where ds.name = :dataset
                   order by ds.id, b.id
              '''

        cur = self.con.cursor()
        cur.execute(sql, {'dataset': dataset})
        data = cur.fetchall()
        if not data:
            raise Exception('Dataset does not exist or has no blocks %s' % dataset)
        else:
            blocks = []
            for blocke in data:
                blocks.append({'name':block})
            return blocks
        
    
    def getBlockReplicas(self, dataset=None):
        if not dataset:  return []
        
        sql = ''' select b.name, n.name, n.se_name
                    from t_dps_dataset ds
                         join t_dps_block b on b.dataset = ds.id
                         join t_dps_block_replica br on br.block = b.id
                         join t_adm_node n on n.id = br.node
                   where ds.name = :dataset
                   order by ds.id, b.id, n.name
              '''

        cur = self.con.cursor()
        cur.execute(sql, {'dataset': dataset})
        data = cur.fetchall()
        if not data:
            raise Exception('%s has no block replicas in TMDB' % dataset)
        else:
            blocks = []
            for block, node, se in data:
                blocks.append({'name':block, 'node':node, 'se':se})
            return blocks


    def getOldBlocks(self, dataset=None):
        if not dataset: return []
        
        sql = ''' select b.name,
                   (select logical_name from xt_dps_file where inblock=b.id and rownum=1) keyfile
                    from xt_dps_dataset ds
                         join xt_dps_block b on b.dataset = ds.id
                   where ds.name = :dataset
                   order by ds.id, b.id
              '''

        cur = self.con.cursor()
        cur.execute(sql, {'dataset': dataset})
        data = cur.fetchall()
        if not data:
            raise Exception('Dataset does not exist or has no blocks %s' % dataset)
        else:
            blocks = []
            for block, keyfile in data:
                blocks.append({'name':block, 'keyfile':keyfile})
            return blocks
        
    
    def getOldBlockReplicas(self, dataset=None):
        if not dataset:  return []
        
        sql = ''' select b.name, n.name, n.se_name,
                         (select logical_name from xt_dps_file where inblock=b.id and rownum=1) keyfile
                    from xt_dps_dataset ds
                         join xt_dps_block b on b.dataset = ds.id
                         join xt_dps_block_replica br on br.block = b.id
                         join xt_adm_node n on n.id = br.node
                   where ds.name = :dataset
                   order by ds.id, b.id, n.name
              '''

        cur = self.con.cursor()
        cur.execute(sql, {'dataset': dataset})
        data = cur.fetchall()
        if not data:
            raise Exception('%s has no block replicas in TMDB' % dataset)
        else:
            blocks = []
            for block, node, se, keyfile in data:
                blocks.append({'name':block, 'node':node, 'se':se, 'keyfile':keyfile})
            return blocks

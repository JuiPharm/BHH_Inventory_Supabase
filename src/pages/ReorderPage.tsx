import { useEffect, useState } from 'react'
import { rpcReorderRecommendation } from '../services/inventoryService'
import { DataTable } from '../components/DataTable'
import { ExportButton } from '../components/ExportButton'
import { RiskBadge } from '../components/StatusBadge'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'

export function ReorderPage(){
 const {selectedWarehouseId}=useAuth(); const {pushToast}=useToast(); const [rows,setRows]=useState<Record<string,unknown>[]>([]); const [loading,setLoading]=useState(false)
 useEffect(()=>{ setLoading(true); rpcReorderRecommendation(selectedWarehouseId).then(d=>setRows(d as Record<string,unknown>[])).catch(e=>pushToast(readableError(e),'error')).finally(()=>setLoading(false)) },[selectedWarehouseId,pushToast])
 return <div className="stack"><div className="toolbar"><ExportButton filename="reorder_recommendation.csv" rows={rows}/></div><DataTable loading={loading} rows={rows} columns={[{key:'code',header:'Code',render:r=><strong>{String(r.item_code||'')}</strong>},{key:'item',header:'Item',render:r=>String(r.item_name||'')},{key:'qty',header:'Available',render:r=>formatNumber(Number(r.qty_available||0),2)},{key:'rop',header:'ROP',render:r=>formatNumber(Number(r.reorder_point||0),2)},{key:'doh',header:'DOH',render:r=>formatNumber(Number(r.days_on_hand||0),1)},{key:'suggest',header:'Suggested Qty',render:r=><strong>{formatNumber(Number(r.suggested_order_qty||0),2)}</strong>},{key:'risk',header:'Risk',render:r=><RiskBadge level={String(r.risk_level||'low')}/>}]} /></div>
}

import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { DataTable } from '../components/DataTable'
import { DateRangePicker } from '../components/DateRangePicker'
import { ExportButton } from '../components/ExportButton'
import { PrintButton } from '../components/PrintButton'
import { rpcStockCard } from '../services/inventoryService'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import type { ItemSearchResult } from '../types'
import { formatDateTime, formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'

export function ReportsPage(){
 const {selectedWarehouseId}=useAuth(); const {pushToast}=useToast(); const today=new Date().toISOString().slice(0,10); const first=today.slice(0,8)+'01'
 const [item,setItem]=useState<ItemSearchResult|null>(null); const [range,setRange]=useState({from:first,to:today}); const [rows,setRows]=useState<Record<string,unknown>[]>([]); const [loading,setLoading]=useState(false)
 async function run(){ if(!item){ pushToast('กรุณาเลือก item ก่อน','warning'); return } setLoading(true); try{ const data=await rpcStockCard({item_id:item.id,warehouse_id:selectedWarehouseId,date_from:range.from,date_to:range.to}); setRows(data as Record<string,unknown>[]) }catch(e){ pushToast(readableError(e),'error') }finally{ setLoading(false) } }
 return <div className="stack"><section className="panel"><h2>Stock Card Report</h2><div className="toolbar"><AsyncItemPicker value={item} onSelect={setItem}/><DateRangePicker from={range.from} to={range.to} onChange={setRange}/><button className="btn" onClick={run}>Run</button><ExportButton filename="stock_card.csv" rows={rows}/><PrintButton/></div></section><DataTable loading={loading} rows={rows} columns={[{key:'time',header:'Time',render:r=>formatDateTime(String(r.performed_at||''))},{key:'type',header:'Type',render:r=>String(r.transaction_type||'')},{key:'ref',header:'Reference',render:r=>String(r.transaction_no||'')},{key:'in',header:'In',render:r=>formatNumber(Number(r.qty_in||0),2)},{key:'out',header:'Out',render:r=>formatNumber(Number(r.qty_out||0),2)},{key:'bal',header:'Balance',render:r=>formatNumber(Number(r.balance_after||0),2)},{key:'remark',header:'Remark',render:r=>String(r.remarks||r.reason||'')}]} /></div>
}

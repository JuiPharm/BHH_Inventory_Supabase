import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcApproveStockCount, rpcCreateStockCount } from '../services/inventoryService'
import { formatDate, formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'

interface CountRow { id:string; count_no:string; warehouse_id:string; count_date:string; status:string; created_at:string }
export function StockCountPage(){
  const { selectedWarehouseId }=useAuth(); const { pushToast }=useToast(); const [rows,setRows]=useState<CountRow[]>([]); const [loading,setLoading]=useState(false)
  async function load(){ setLoading(true); try{ let q=supabase.from('stock_counts').select('id,count_no,warehouse_id,count_date,status,created_at').order('created_at',{ascending:false}).limit(30); if(selectedWarehouseId) q=q.eq('warehouse_id',selectedWarehouseId); const {data,error}=await q; if(error) throw error; setRows((data||[]) as CountRow[]) }catch(e){ pushToast(readableError(e),'error') }finally{ setLoading(false) } }
  useEffect(()=>{ load() },[selectedWarehouseId])
  async function create(){ if(!selectedWarehouseId){ pushToast('กรุณาเลือกคลัง','warning'); return } try{ await rpcCreateStockCount(selectedWarehouseId); pushToast('สร้าง count session สำเร็จ','success'); await load() }catch(e){ pushToast(readableError(e),'error') } }
  async function approve(id:string){ try{ await rpcApproveStockCount(id); pushToast('อนุมัติ stock count สำเร็จ','success'); await load() }catch(e){ pushToast(readableError(e),'error') } }
  return <div className="stack"><div className="toolbar"><button className="btn" onClick={create}>Create Count Session</button></div><DataTable loading={loading} rows={rows} columns={[{key:'no',header:'Count No',render:r=><strong>{r.count_no}</strong>},{key:'date',header:'Date',render:r=>formatDate(r.count_date)},{key:'status',header:'Status',render:r=>r.status},{key:'action',header:'Action',render:r=><button className="btn secondary" disabled={r.status==='approved'} onClick={()=>approve(r.id)}>Approve</button>}]} /><p className="hint">หลังสร้าง session ให้เปิดตาราง stock_count_items ใน Admin/SQL เพื่อกรอก counted_qty หรือสร้างหน้าจอ count detail เพิ่มเติมตาม workflow หน่วยงาน</p></div>
}

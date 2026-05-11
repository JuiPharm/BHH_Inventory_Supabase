import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { SearchInput } from '../components/SearchInput'
import { ExportButton } from '../components/ExportButton'
import { useToast } from '../state/ToastContext'
import { formatDateTime } from '../utils/format'
import { readableError } from '../utils/errors'

interface AuditRow { id:string; table_name:string; record_id:string; action:string; old_data:unknown; new_data:unknown; changed_at:string; changed_by:string|null }
export function AuditLogPage(){
 const {pushToast}=useToast(); const [keyword,setKeyword]=useState(''); const [rows,setRows]=useState<AuditRow[]>([]); const [loading,setLoading]=useState(false)
 useEffect(()=>{ load() },[keyword])
 async function load(){ setLoading(true); try{ let q=supabase.from('audit_logs').select('*').order('changed_at',{ascending:false}).limit(100); if(keyword.trim()) q=q.or(`table_name.ilike.%${keyword}%,action.ilike.%${keyword}%,record_id.ilike.%${keyword}%`); const {data,error}=await q; if(error) throw error; setRows((data||[]) as AuditRow[]) }catch(e){ pushToast(readableError(e),'error') }finally{ setLoading(false) } }
 return <div className="stack"><div className="toolbar"><SearchInput value={keyword} onChange={setKeyword} placeholder="ค้นหา audit log"/><ExportButton filename="audit_logs.csv" rows={rows as unknown as Record<string,unknown>[]} /></div><DataTable loading={loading} rows={rows} columns={[{key:'time',header:'Time',render:r=>formatDateTime(r.changed_at)},{key:'table',header:'Table',render:r=><strong>{r.table_name}</strong>},{key:'action',header:'Action',render:r=>r.action},{key:'record',header:'Record',render:r=><code>{r.record_id}</code>},{key:'changed_by',header:'Changed by',render:r=>r.changed_by || '-'}]} /></div>
}

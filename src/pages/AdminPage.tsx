import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { StatusBadge } from '../components/StatusBadge'
import { useToast } from '../state/ToastContext'
import { readableError } from '../utils/errors'

export function AdminPage(){
 const {pushToast}=useToast(); const [profiles,setProfiles]=useState<Record<string,unknown>[]>([]); const [warehouses,setWarehouses]=useState<Record<string,unknown>[]>([]); const [loading,setLoading]=useState(false)
 useEffect(()=>{ load() },[])
 async function load(){ setLoading(true); try{ const [p,w]=await Promise.all([supabase.from('profiles').select('id,email,full_name,is_active,roles(role_name)').limit(100),supabase.from('warehouses').select('id,warehouse_code,warehouse_name,is_active').limit(100)]); if(p.error) throw p.error; if(w.error) throw w.error; setProfiles(p.data as Record<string,unknown>[] || []); setWarehouses(w.data as Record<string,unknown>[] || []) }catch(e){ pushToast(readableError(e),'error') }finally{ setLoading(false) } }
 return <div className="grid two"><section className="panel"><h2>Users / Profiles</h2><DataTable loading={loading} rows={profiles} columns={[{key:'email',header:'Email',render:r=>String(r.email||'')},{key:'name',header:'Name',render:r=>String(r.full_name||'')},{key:'role',header:'Role',render:r=>String((r.roles as {role_name?:string}|null)?.role_name || '-')},{key:'active',header:'Status',render:r=><StatusBadge tone={Boolean(r.is_active)?'green':'gray'}>{Boolean(r.is_active)?'Active':'Inactive'}</StatusBadge>}]} /></section><section className="panel"><h2>Warehouses</h2><DataTable loading={loading} rows={warehouses} columns={[{key:'code',header:'Code',render:r=><strong>{String(r.warehouse_code||'')}</strong>},{key:'name',header:'Name',render:r=>String(r.warehouse_name||'')},{key:'active',header:'Status',render:r=><StatusBadge tone={Boolean(r.is_active)?'green':'gray'}>{Boolean(r.is_active)?'Active':'Inactive'}</StatusBadge>}]} /><p className="hint">Master data เพิ่มเติมแนะนำจัดการผ่าน controlled admin screen หรือ Supabase SQL ตามสิทธิ์ manager/admin</p></section></div>
}

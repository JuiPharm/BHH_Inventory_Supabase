import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { SearchInput } from '../components/SearchInput'
import { Pagination } from '../components/Pagination'
import { StatusBadge } from '../components/StatusBadge'
import { FormDrawer } from '../components/FormDrawer'
import { useToast } from '../state/ToastContext'
import { readableError } from '../utils/errors'

interface ItemRow { id: string; item_code: string; barcode: string | null; item_name: string; generic_name: string | null; brand_name: string | null; is_active: boolean; is_high_alert: boolean; is_controlled: boolean; min_stock: number; reorder_point: number }
const blank = { item_code: '', barcode: '', item_name: '', generic_name: '', brand_name: '', min_stock: 0, max_stock: 0, reorder_point: 0, safety_stock: 0, pack_size: '1', is_lot_tracked: true, is_expiry_tracked: true, is_controlled: false, is_high_alert: false, is_active: true }

export function ItemsPage() {
  const { pushToast } = useToast()
  const [rows, setRows] = useState<ItemRow[]>([])
  const [total, setTotal] = useState(0)
  const [keyword, setKeyword] = useState('')
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [drawer, setDrawer] = useState(false)
  const [form, setForm] = useState(blank)
  const pageSize = 20

  async function load() {
    setLoading(true)
    try {
      let query = supabase.from('items').select('id,item_code,barcode,item_name,generic_name,brand_name,is_active,is_high_alert,is_controlled,min_stock,reorder_point', { count: 'exact' })
      if (keyword.trim()) query = query.or(`item_code.ilike.%${keyword}%,item_name.ilike.%${keyword}%,generic_name.ilike.%${keyword}%,brand_name.ilike.%${keyword}%,barcode.ilike.%${keyword}%`)
      const from = (page - 1) * pageSize
      const { data, error, count } = await query.order('item_name').range(from, from + pageSize - 1)
      if (error) throw error
      setRows((data || []) as ItemRow[])
      setTotal(count || 0)
    } catch (error) { pushToast(readableError(error), 'error') }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [keyword, page])

  async function save(e: React.FormEvent) {
    e.preventDefault()
    try {
      const { error } = await supabase.from('items').insert(form)
      if (error) throw error
      pushToast('บันทึก Item สำเร็จ', 'success')
      setDrawer(false); setForm(blank); await load()
    } catch (error) { pushToast(readableError(error), 'error') }
  }

  return <div className="stack"><div className="toolbar"><SearchInput value={keyword} onChange={v => { setPage(1); setKeyword(v) }} placeholder="ค้นหา item code, barcode, ชื่อยา/สินค้า" /><button className="btn" onClick={() => setDrawer(true)}><Plus size={16}/> Add Item</button></div><DataTable loading={loading} rows={rows} columns={[{key:'code',header:'Code',render:r=><strong>{r.item_code}</strong>},{key:'name',header:'Item',render:r=><div><b>{r.item_name}</b><small>{r.generic_name || r.brand_name || '-'}</small></div>},{key:'flag',header:'Flags',render:r=><div className="badges">{r.is_high_alert && <StatusBadge tone="red">High Alert</StatusBadge>}{r.is_controlled && <StatusBadge tone="amber">Controlled</StatusBadge>}</div>},{key:'min',header:'Min/ROP',render:r=>`${r.min_stock}/${r.reorder_point}`},{key:'status',header:'Status',render:r=><StatusBadge tone={r.is_active?'green':'gray'}>{r.is_active?'Active':'Inactive'}</StatusBadge>}]} /><Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} /><FormDrawer open={drawer} title="Add Item" onClose={() => setDrawer(false)}><form className="form-grid" onSubmit={save}><label>Item code<input required value={form.item_code} onChange={e=>setForm({...form,item_code:e.target.value})}/></label><label>Barcode<input value={form.barcode} onChange={e=>setForm({...form,barcode:e.target.value})}/></label><label className="span-2">Item name<input required value={form.item_name} onChange={e=>setForm({...form,item_name:e.target.value})}/></label><label>Generic name<input value={form.generic_name} onChange={e=>setForm({...form,generic_name:e.target.value})}/></label><label>Brand name<input value={form.brand_name} onChange={e=>setForm({...form,brand_name:e.target.value})}/></label><label>Min stock<input type="number" value={form.min_stock} onChange={e=>setForm({...form,min_stock:Number(e.target.value)})}/></label><label>Reorder point<input type="number" value={form.reorder_point} onChange={e=>setForm({...form,reorder_point:Number(e.target.value)})}/></label><label><input type="checkbox" checked={form.is_expiry_tracked} onChange={e=>setForm({...form,is_expiry_tracked:e.target.checked})}/> Track expiry</label><label><input type="checkbox" checked={form.is_lot_tracked} onChange={e=>setForm({...form,is_lot_tracked:e.target.checked})}/> Track lot</label><label><input type="checkbox" checked={form.is_controlled} onChange={e=>setForm({...form,is_controlled:e.target.checked})}/> Controlled</label><label><input type="checkbox" checked={form.is_high_alert} onChange={e=>setForm({...form,is_high_alert:e.target.checked})}/> High alert</label><div className="drawer-actions"><button className="btn secondary" type="button" onClick={()=>setDrawer(false)}>Cancel</button><button className="btn" type="submit">Save</button></div></form></FormDrawer></div>
}

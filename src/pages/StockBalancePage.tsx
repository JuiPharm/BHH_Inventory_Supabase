import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { SearchInput } from '../components/SearchInput'
import { StatusBadge } from '../components/StatusBadge'
import { ExportButton } from '../components/ExportButton'
import { Pagination } from '../components/Pagination'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import type { CurrentStockRow } from '../types'
import { formatCurrency, formatDate, formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'

export function StockBalancePage() {
  const { selectedWarehouseId } = useAuth()
  const { pushToast } = useToast()
  const [rows, setRows] = useState<CurrentStockRow[]>([])
  const [total, setTotal] = useState(0)
  const [keyword, setKeyword] = useState('')
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const pageSize = 20

  useEffect(() => { load() }, [selectedWarehouseId, keyword, page])
  async function load() {
    setLoading(true)
    try {
      let query = supabase.from('current_stock_view').select('*', { count: 'exact' })
      if (selectedWarehouseId) query = query.eq('warehouse_id', selectedWarehouseId)
      if (keyword.trim()) query = query.or(`item_code.ilike.%${keyword}%,item_name.ilike.%${keyword}%,generic_name.ilike.%${keyword}%,brand_name.ilike.%${keyword}%,lot_no.ilike.%${keyword}%`)
      const from = (page - 1) * pageSize
      const { data, error, count } = await query.order('item_name').range(from, from + pageSize - 1)
      if (error) throw error
      setRows((data || []) as CurrentStockRow[]); setTotal(count || 0)
    } catch (error) { pushToast(readableError(error), 'error') }
    finally { setLoading(false) }
  }
  return <div className="stack"><div className="toolbar"><SearchInput value={keyword} onChange={v => { setPage(1); setKeyword(v) }} placeholder="ค้นหา stock / lot / item" /><ExportButton filename="current_stock.csv" rows={rows as unknown as Record<string, unknown>[]} /></div><DataTable loading={loading} rows={rows} columns={[{key:'item',header:'Item',render:r=><div><b>{r.item_code}</b><small>{r.item_name}</small></div>},{key:'warehouse',header:'Warehouse',render:r=>r.warehouse_name},{key:'lot',header:'Lot / Expiry',render:r=><div><b>{r.lot_no || '-'}</b><small>{formatDate(r.expiry_date)}</small></div>},{key:'qty',header:'Available',render:r=><strong>{formatNumber(r.qty_available,2)}</strong>},{key:'value',header:'Value',render:r=>formatCurrency(r.total_value)},{key:'status',header:'Status',render:r=><div className="badges"><StatusBadge tone={r.stock_status==='out_of_stock'?'red':r.stock_status==='low_stock'?'amber':'green'}>{r.stock_status}</StatusBadge><StatusBadge tone={r.expiry_status==='expired'?'red':r.expiry_status==='near_expiry'?'amber':'green'}>{r.expiry_status}</StatusBadge></div>}]} /><Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} /></div>
}

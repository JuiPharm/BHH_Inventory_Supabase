import { useEffect, useState } from 'react'
import { rpcDashboardSummary } from '../services/inventoryService'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import type { DashboardSummary } from '../types'
import { formatCurrency, formatDateTime, formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'
import { SkeletonCards } from '../components/LoadingSpinner'
import { DataTable } from '../components/DataTable'

export function DashboardPage() {
  const { selectedWarehouseId } = useAuth()
  const { pushToast } = useToast()
  const [summary, setSummary] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    rpcDashboardSummary(selectedWarehouseId)
      .then(data => setSummary(data as DashboardSummary))
      .catch(error => pushToast(readableError(error), 'error'))
      .finally(() => setLoading(false))
  }, [selectedWarehouseId, pushToast])

  if (loading) return <SkeletonCards />
  const kpis = [
    ['Total SKUs', summary?.total_skus, 'blue'],
    ['Active SKUs', summary?.active_skus, 'green'],
    ['Inventory Value', formatCurrency(summary?.total_inventory_value || 0), 'blue'],
    ['Low Stock', summary?.low_stock_items, 'amber'],
    ['Out of Stock', summary?.out_of_stock_items, 'red'],
    ['Near Expiry Lots', summary?.near_expiry_lots, 'amber'],
    ['Expired Lots', summary?.expired_lots, 'red'],
    ['Movements This Month', summary?.movements_this_month, 'blue'],
    ['Issue Value This Month', formatCurrency(summary?.issue_value_this_month || 0), 'red'],
    ['Receive Value This Month', formatCurrency(summary?.receive_value_this_month || 0), 'green']
  ]
  const recent = (summary?.recent_transactions || []) as Record<string, unknown>[]
  const category = (summary?.inventory_value_by_category || []) as Record<string, unknown>[]

  return <div className="stack"><div className="kpi-grid">{kpis.map(([label, value, tone]) => <div className={`kpi-card border-${tone}`} key={label as string}><span>{label}</span><strong>{typeof value === 'number' ? formatNumber(value) : value}</strong></div>)}</div><div className="grid two"><section className="panel"><h2>Inventory Value by Category</h2><div className="bar-list">{category.map((row, i) => { const value = Number(row.total_value || 0); const max = Math.max(...category.map(r => Number(r.total_value || 0)), 1); return <div className="bar-row" key={i}><span>{String(row.category_name || 'Uncategorized')}</span><div><b style={{ width: `${Math.max(4, value / max * 100)}%` }} /></div><em>{formatCurrency(value)}</em></div> })}</div></section><section className="panel"><h2>Recent Transactions</h2><DataTable rows={recent} columns={[{key:'performed_at', header:'เวลา', render:r=>formatDateTime(String(r.performed_at || ''))},{key:'type', header:'ประเภท', render:r=>String(r.transaction_type || '-')},{key:'item', header:'รายการ', render:r=>String(r.item_name || '-')},{key:'qty', header:'จำนวน', render:r=>formatNumber(Number(r.qty_in || 0) - Number(r.qty_out || 0))}]} /></section></div></div>
}

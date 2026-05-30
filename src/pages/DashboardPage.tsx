import { useEffect, useState } from 'react'
import { rpcDashboardSummary } from '../services/inventoryService'
import { supabase } from '../lib/supabaseClient'
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
  const [lowStockList, setLowStockList] = useState<any[]>([])
  const [nearExpiryList, setNearExpiryList] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true
    setLoading(true)
    
    async function load() {
      try {
        const [dashRes, lowRes, expRes] = await Promise.all([
          rpcDashboardSummary(selectedWarehouseId),
          selectedWarehouseId 
            ? supabase.from('low_stock_view').select('*').eq('warehouse_id', selectedWarehouseId).order('qty_available', { ascending: true }).limit(5)
            : supabase.from('low_stock_view').select('*').order('qty_available', { ascending: true }).limit(5),
          selectedWarehouseId
            ? supabase.from('near_expiry_view').select('*').eq('warehouse_id', selectedWarehouseId).order('expiry_date', { ascending: true }).limit(5)
            : supabase.from('near_expiry_view').select('*').order('expiry_date', { ascending: true }).limit(5)
        ])
        
        if (!mounted) return
        setSummary(dashRes as DashboardSummary)
        setLowStockList(lowRes.data || [])
        setNearExpiryList(expRes.data || [])
      } catch (error) {
        if (mounted) pushToast(readableError(error), 'error')
      } finally {
        if (mounted) setLoading(false)
      }
    }
    
    load()
    return () => { mounted = false }
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

  return (
    <div className="stack">
      <div className="kpi-grid">
        {kpis.map(([label, value, tone]) => (
          <div className={`kpi-card border-${tone}`} key={label as string}>
            <span>{label}</span>
            <strong>{typeof value === 'number' ? formatNumber(value) : value}</strong>
          </div>
        ))}
      </div>

      <div className="grid two">
        <section className="panel" style={{ borderTop: '4px solid var(--red)' }}>
          <h2 style={{ color: 'var(--red)' }}>🚨 Critical Low Stock</h2>
          <DataTable 
            rows={lowStockList} 
            columns={[
              { key: 'item', header: 'Item', render: r => String(r.item_name || '-') },
              { key: 'avail', header: 'Available', render: r => <strong style={{ color: 'var(--red)' }}>{formatNumber(Number(r.qty_available))}</strong> },
              { key: 'min', header: 'Min Level', render: r => formatNumber(Number(r.min_level)) }
            ]} 
          />
          {lowStockList.length === 0 && <p className="hint">No low stock items</p>}
        </section>

        <section className="panel" style={{ borderTop: '4px solid var(--amber)' }}>
          <h2 style={{ color: 'var(--amber)' }}>⚠️ Near Expiry Lots</h2>
          <DataTable 
            rows={nearExpiryList} 
            columns={[
              { key: 'item', header: 'Item', render: r => String(r.item_name || '-') },
              { key: 'lot', header: 'Lot ID', render: r => String(r.lot_id || '-') },
              { key: 'exp', header: 'Expiry', render: r => <span style={{ color: 'var(--amber)', fontWeight: 'bold' }}>{formatDateTime(String(r.expiry_date || '')).slice(0, 10)}</span> },
              { key: 'qty', header: 'Qty', render: r => formatNumber(Number(r.qty_on_hand)) }
            ]} 
          />
          {nearExpiryList.length === 0 && <p className="hint">No near expiry lots</p>}
        </section>
      </div>

      <div className="grid two">
        <section className="panel">
          <h2>Inventory Value by Category</h2>
          <div className="bar-list">
            {category.map((row, i) => { 
              const value = Number(row.total_value || 0)
              const max = Math.max(...category.map(r => Number(r.total_value || 0)), 1)
              return (
                <div className="bar-row" key={i}>
                  <span>{String(row.category_name || 'Uncategorized')}</span>
                  <div><b style={{ width: `${Math.max(4, value / max * 100)}%` }} /></div>
                  <em>{formatCurrency(value)}</em>
                </div>
              ) 
            })}
          </div>
        </section>
        
        <section className="panel">
          <h2>Recent Transactions</h2>
          <DataTable 
            rows={recent} 
            columns={[
              {key:'performed_at', header:'เวลา', render:r=>formatDateTime(String(r.performed_at || ''))},
              {key:'type', header:'ประเภท', render:r=>String(r.transaction_type || '-')},
              {key:'item', header:'รายการ', render:r=>String(r.item_name || '-')},
              {key:'qty', header:'จำนวน', render:r=>formatNumber(Number(r.qty_in || 0) - Number(r.qty_out || 0))}
            ]} 
          />
        </section>
      </div>
    </div>
  )
}

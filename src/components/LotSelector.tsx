import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { formatDate, formatNumber } from '../utils/format'

interface Lot {
  lot_id: string
  lot_no: string | null
  expiry_date: string | null
  qty_available: number
}

interface Props {
  itemId: string
  warehouseId: string | null
  value: string
  onChange: (lotId: string) => void
  disabled?: boolean
}

export function LotSelector({ itemId, warehouseId, value, onChange, disabled }: Props) {
  const [lots, setLots] = useState<Lot[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!itemId || !warehouseId) {
      setLots([])
      return
    }

    let mounted = true

    async function load() {
      setLoading(true)
      try {
        const { data, error } = await supabase
          .from('current_stock_view')
          .select('lot_id, lot_no, expiry_date, qty_available')
          .eq('item_id', itemId)
          .eq('warehouse_id', warehouseId)
          .gt('qty_available', 0)
          .not('lot_id', 'is', null)
          .order('expiry_date', { ascending: true, nullsFirst: false })

        if (error) throw error
        if (!mounted) return

        const nextLots = (data || []) as Lot[]
        setLots(nextLots)
        if (nextLots.length > 0 && !value) {
          onChange(nextLots[0].lot_id)
        }
      } finally {
        if (mounted) setLoading(false)
      }
    }

    load()
    return () => { mounted = false }
  }, [itemId, warehouseId])

  if (!itemId) return <select disabled><option>Select item first</option></select>
  if (!warehouseId) return <select disabled><option>Select warehouse first</option></select>
  if (loading) return <select disabled><option>Loading lots...</option></select>
  if (lots.length === 0) return <select disabled><option>No stock available</option></select>

  return (
    <select value={value} onChange={e => onChange(e.target.value)} disabled={disabled}>
      <option value="">-- Select Lot (FEFO Recommended) --</option>
      {lots.map((lot, idx) => {
        const isOldest = idx === 0
        const lotLabel = lot.lot_no || lot.lot_id.slice(0, 8)
        return (
          <option key={lot.lot_id} value={lot.lot_id}>
            {lotLabel} · Exp: {formatDate(lot.expiry_date)} · Qty: {formatNumber(lot.qty_available, 2)}{isOldest ? ' · FEFO' : ''}
          </option>
        )
      })}
    </select>
  )
}

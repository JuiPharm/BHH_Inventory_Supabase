import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { formatNumber } from '../utils/format'

interface Lot {
  lot_id: string
  expiry_date: string | null
  qty_on_hand: number
}

interface Props {
  itemId: string
  warehouseId: string
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
    async function load() {
      setLoading(true)
      try {
        const { data, error } = await supabase
          .from('stock_balances')
          .select('lot_id, expiry_date, qty_on_hand')
          .eq('item_id', itemId)
          .eq('warehouse_id', warehouseId)
          .gt('qty_on_hand', 0)
          .order('expiry_date', { ascending: true })

        if (!error && data) {
          setLots(data)
          // If there's only one lot, or if value is empty and we want to auto-select the oldest (FEFO)
          if (data.length > 0 && !value) {
            onChange(data[0].lot_id)
          }
        }
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [itemId, warehouseId]) // Intentionally omit value/onChange to prevent loops

  if (!itemId) return <select disabled><option>Select Item first</option></select>
  if (loading) return <select disabled><option>Loading lots...</option></select>
  if (lots.length === 0) return <select disabled><option>No stock available</option></select>

  return (
    <select value={value} onChange={e => onChange(e.target.value)} disabled={disabled}>
      <option value="">-- Select Lot (FEFO Recommended) --</option>
      {lots.map((lot, idx) => {
        const isOldest = idx === 0
        const displayDate = lot.expiry_date ? new Date(lot.expiry_date).toLocaleDateString() : 'No expiry'
        return (
          <option key={lot.lot_id} value={lot.lot_id}>
            Lot: {lot.lot_id} (Exp: {displayDate}) - Qty: {formatNumber(lot.qty_on_hand)}
            {isOldest ? ' ⭐ [OLDEST]' : ''}
          </option>
        )
      })}
    </select>
  )
}

import { useEffect, useState } from 'react'
import { rpcSearchItems } from '../services/inventoryService'
import type { ItemSearchResult } from '../types'
import { useDebouncedValue } from '../utils/debounce'

export function AsyncItemPicker({ value, onSelect, placeholder = 'พิมพ์รหัส/ชื่อยา/สินค้า...' }: { value?: ItemSearchResult | null; onSelect: (item: ItemSearchResult) => void; placeholder?: string }) {
  const [keyword, setKeyword] = useState(value ? `${value.item_code} ${value.item_name}` : '')
  const debounced = useDebouncedValue(keyword, 300)
  const [rows, setRows] = useState<ItemSearchResult[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    let mounted = true
    if (debounced.trim().length < 2) { setRows([]); return }
    setLoading(true)
    rpcSearchItems(debounced.trim())
      .then(data => mounted && setRows(data as ItemSearchResult[]))
      .catch(() => mounted && setRows([]))
      .finally(() => mounted && setLoading(false))
    return () => { mounted = false }
  }, [debounced])

  return <div className="typeahead"><input value={keyword} onChange={e => setKeyword(e.target.value)} placeholder={placeholder} />{loading && <div className="typeahead-status">ค้นหา...</div>}{rows.length > 0 && <div className="typeahead-menu">{rows.map(item => <button key={item.id} type="button" onClick={() => { onSelect(item); setKeyword(`${item.item_code} ${item.item_name}`); setRows([]) }}><strong>{item.item_code}</strong><span>{item.item_name}</span>{item.is_high_alert && <em>High alert</em>}</button>)}</div>}</div>
}

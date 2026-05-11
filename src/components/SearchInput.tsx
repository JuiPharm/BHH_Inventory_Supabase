import { Search } from 'lucide-react'

export function SearchInput({ value, onChange, placeholder = 'ค้นหา...' }: { value: string; onChange: (value: string) => void; placeholder?: string }) {
  return <div className="search-box"><Search size={18} /><input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} /></div>
}

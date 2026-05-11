type Tone = 'green' | 'amber' | 'red' | 'blue' | 'gray'
export function StatusBadge({ children, tone = 'gray' }: { children: string; tone?: Tone }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}
export function RiskBadge({ level }: { level?: string | null }) {
  const value = (level || 'low').toLowerCase()
  const tone = value === 'critical' ? 'red' : value === 'high' ? 'amber' : value === 'medium' ? 'blue' : 'green'
  return <StatusBadge tone={tone}>{value.toUpperCase()}</StatusBadge>
}

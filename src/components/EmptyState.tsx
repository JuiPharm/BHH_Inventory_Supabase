export function EmptyState({ title = 'ไม่พบข้อมูล', detail = 'ลองเปลี่ยนคำค้นหาหรือตัวกรองอีกครั้ง' }: { title?: string; detail?: string }) {
  return <div className="empty-state"><div className="empty-icon">∅</div><h3>{title}</h3><p>{detail}</p></div>
}

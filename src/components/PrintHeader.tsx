interface Props {
  title: string
  reference?: string
  date?: string
  warehouse?: string
  user?: string
}

export function PrintHeader({ title, reference, date, warehouse, user }: Props) {
  return (
    <div className="print-only print-header">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid #000', paddingBottom: 16, marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: '0 0 8px 0', fontSize: 24 }}>Bangkok Hospital Hatyai</h1>
          <p style={{ margin: 0, fontSize: 14 }}>Inventory Management System</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <h2 style={{ margin: '0 0 8px 0', fontSize: 20, textTransform: 'uppercase' }}>{title}</h2>
          {reference && <p style={{ margin: '0 0 4px 0', fontSize: 14 }}><strong>Ref:</strong> {reference}</p>}
          {date && <p style={{ margin: '0 0 4px 0', fontSize: 14 }}><strong>Date:</strong> {date}</p>}
        </div>
      </div>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 24, fontSize: 14 }}>
        {warehouse && <div><strong>Warehouse:</strong> {warehouse}</div>}
        {user && <div><strong>Issued By:</strong> {user}</div>}
      </div>
    </div>
  )
}

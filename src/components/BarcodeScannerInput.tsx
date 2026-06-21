import { Camera, Keyboard, QrCode, ScanLine, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

interface Props {
  onScan: (code: string) => void
  placeholder?: string
  loading?: boolean
}

const BARCODE_FORMATS = [
  'qr_code',
  'code_128',
  'code_39',
  'code_93',
  'ean_13',
  'ean_8',
  'upc_a',
  'upc_e',
  'itf',
  'codabar',
  'data_matrix',
  'pdf417'
]

export function BarcodeScannerInput({ onScan, placeholder = 'Scan QR / Barcode or type code + Enter...', loading }: Props) {
  const [value, setValue] = useState('')
  const [cameraOpen, setCameraOpen] = useState(false)
  const [cameraError, setCameraError] = useState('')
  const [cameraStatus, setCameraStatus] = useState('Ready to scan QR / barcode')
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<number | null>(null)
  const lastCodeRef = useRef('')

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' && value.trim()) {
      onScan(value.trim())
      setValue('')
    }
  }

  function stopCamera() {
    if (timerRef.current) window.clearTimeout(timerRef.current)
    timerRef.current = null
    streamRef.current?.getTracks().forEach(track => track.stop())
    streamRef.current = null
  }

  useEffect(() => {
    if (!cameraOpen) {
      stopCamera()
      return
    }

    let cancelled = false

    async function startCamera() {
      setCameraError('')
      setCameraStatus('Starting camera...')

      if (!window.BarcodeDetector) {
        setCameraError('This browser does not support camera QR/barcode detection. You can still use a hardware scanner or type the code.')
        setCameraStatus('Camera scan unavailable')
        return
      }

      if (!navigator.mediaDevices?.getUserMedia) {
        setCameraError('Camera access is not available in this browser.')
        setCameraStatus('Camera scan unavailable')
        return
      }

      try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false })
        if (cancelled) {
          stream.getTracks().forEach(track => track.stop())
          return
        }

        streamRef.current = stream
        if (videoRef.current) {
          videoRef.current.srcObject = stream
          await videoRef.current.play()
        }

        const detector = new window.BarcodeDetector({ formats: BARCODE_FORMATS })
        setCameraStatus('Point the camera at a QR code or barcode')

        const scanFrame = async () => {
          if (cancelled || !videoRef.current) return
          try {
            const codes = await detector.detect(videoRef.current)
            const code = codes[0]?.rawValue?.trim()
            if (code && code !== lastCodeRef.current) {
              lastCodeRef.current = code
              onScan(code)
              setCameraStatus(`Scanned: ${code}`)
              setCameraOpen(false)
              return
            }
          } catch {
            setCameraStatus('Looking for a readable code...')
          }
          timerRef.current = window.setTimeout(scanFrame, 250)
        }

        scanFrame()
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Unable to open camera.'
        setCameraError(message)
        setCameraStatus('Camera permission is required')
      }
    }

    startCamera()
    return () => {
      cancelled = true
      stopCamera()
    }
  }, [cameraOpen, onScan])

  return (
    <>
      <div className="scanner-input">
        <div className="input-icon scanner-field">
          <ScanLine size={18} style={{ color: 'var(--muted)' }} />
          <input
            type="text"
            placeholder={loading ? 'Searching...' : placeholder}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={loading}
            autoComplete="off"
          />
        </div>
        <button className="btn scan-btn" type="button" onClick={() => setCameraOpen(true)} disabled={loading} title="Open camera scanner">
          <QrCode size={20} />
          <span>Scan</span>
        </button>
      </div>

      {cameraOpen && (
        <div className="modal-backdrop scanner-modal" role="dialog" aria-modal="true" aria-label="QR and barcode scanner">
          <div className="modal-card scanner-card">
            <div className="scanner-head">
              <div>
                <h3><Camera size={20} /> QR / Barcode Scanner</h3>
                <p>{cameraStatus}</p>
              </div>
              <button className="icon-btn light" type="button" onClick={() => setCameraOpen(false)} aria-label="Close scanner"><X size={18} /></button>
            </div>
            <div className="scanner-view">
              <video ref={videoRef} playsInline muted />
              <div className="scanner-frame" />
            </div>
            {cameraError && <div className="scanner-error"><Keyboard size={18} />{cameraError}</div>}
            <div className="panel-actions">
              <button className="btn secondary" type="button" onClick={() => setCameraOpen(false)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

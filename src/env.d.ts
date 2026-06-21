/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string
  readonly VITE_SUPABASE_ANON_KEY: string
  readonly VITE_APP_NAME?: string
  readonly VITE_BASE_PATH?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

interface BarcodeDetectorOptions {
  formats?: string[]
}

interface DetectedBarcode {
  rawValue: string
  format?: string
  boundingBox?: DOMRectReadOnly
}

interface BarcodeDetector {
  detect(image: HTMLVideoElement | HTMLImageElement | HTMLCanvasElement | ImageBitmap): Promise<DetectedBarcode[]>
}

interface BarcodeDetectorConstructor {
  new(options?: BarcodeDetectorOptions): BarcodeDetector
  getSupportedFormats?: () => Promise<string[]>
}

interface Window {
  BarcodeDetector?: BarcodeDetectorConstructor
}

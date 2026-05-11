# Netlify Deployment Guide

## 1. Upload Code to GitHub

```bash
git add .
git commit -m "Complete BHH Inventory Netlify build"
git push
```

Do not commit:

```txt
node_modules
dist
.env
.env.local
.env.production
```

## 2. Import Project in Netlify

Go to Netlify:

```txt
Add new site
→ Import an existing project
→ GitHub
→ Select repository
```

## 3. Build Settings

```txt
Build command: npm run build
Publish directory: dist
Base directory: leave blank
```

## 4. Environment Variables

Netlify > Site configuration > Environment variables:

```txt
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
VITE_APP_NAME=BHH Inventory Management System
VITE_BASE_PATH=/
```

Do not add Supabase `service_role` key.

## 5. Supabase Auth Redirect URLs

Supabase > Authentication > URL Configuration:

```txt
Site URL:
https://your-site-name.netlify.app

Additional Redirect URLs:
http://localhost:5173/**
https://your-site-name.netlify.app/**
https://deploy-preview-*--your-site-name.netlify.app/**
```

## 6. Deploy

Click Deploy. After deploy, test:

```txt
/
/dashboard
/items
/receive
/issue
/reports
```

Refresh every route. Netlify must return `index.html` because this app uses SPA routing.

## 7. Troubleshooting

### Blank page
Check environment variables. Vite requires env variables to start with `VITE_`.

### 404 after refresh
Check `netlify.toml` and `public/_redirects`.

### Login redirects to wrong URL
Update Supabase Auth URL Configuration.

### RLS permission denied
Check user profile, role, and `user_warehouse_access`.

### Receive/Issue fails
Do not update stock balances directly. Use RPC and verify user warehouse permission.

# Testing Checklist

## Build

- [ ] `npm install` completes
- [ ] `npm run build` passes
- [ ] Netlify deploy passes
- [ ] Direct route refresh does not 404

## Supabase Setup

- [ ] All SQL files run successfully
- [ ] RLS is enabled
- [ ] Storage bucket `item-images` exists
- [ ] Default roles exist
- [ ] First admin profile exists

## Authentication

- [ ] Login works
- [ ] Logout works
- [ ] Reset password email works
- [ ] Inactive user cannot use app

## Role / RLS

- [ ] Super admin sees all warehouses
- [ ] Staff sees assigned warehouse
- [ ] Viewer cannot write
- [ ] Auditor can read audit logs
- [ ] Staff cannot read unauthorized warehouse data

## Item Master

- [ ] Add item
- [ ] Search item
- [ ] High alert flag displays
- [ ] Controlled flag displays
- [ ] Inactive item does not appear in async picker

## Receive Stock

- [ ] Qty <= 0 rejected
- [ ] Negative unit cost rejected
- [ ] Expiry required when item tracks expiry
- [ ] Lot required when item tracks lot
- [ ] Receive creates receive document
- [ ] Receive creates/updates stock lot
- [ ] Receive increases stock balance
- [ ] Receive creates stock transaction

## Issue Stock

- [ ] Qty <= 0 rejected
- [ ] Issue over available stock rejected
- [ ] Expired lot cannot be issued
- [ ] FEFO lot selection works
- [ ] Controlled/high alert item requires reason
- [ ] Issue decreases stock balance
- [ ] Issue creates stock transaction

## Adjustment

- [ ] Reason required
- [ ] Negative adjustment cannot make stock negative
- [ ] Adjustment creates document
- [ ] Adjustment creates stock transaction
- [ ] Audit log is created

## Transfer

- [ ] Source and destination cannot be same
- [ ] Insufficient stock rejected
- [ ] Source stock decreases
- [ ] Destination stock increases
- [ ] Transfer out and transfer in transactions created

## Stock Count

- [ ] Create count session
- [ ] Snapshot system quantity created
- [ ] Counted quantity can be entered
- [ ] Approve creates count adjustment
- [ ] Approved session cannot be approved twice

## Dashboard / Reports

- [ ] Dashboard KPI loads
- [ ] Low stock count correct
- [ ] Near expiry count correct
- [ ] Stock card report works
- [ ] CSV export works
- [ ] Print report works

## Audit

- [ ] Insert/update/delete on master data logs audit
- [ ] Auditor can view audit logs
- [ ] Normal staff cannot delete audit logs

-- ==============================================================================
-- تَرميم (Tarmeem) - Supabase Database Schema & Storage Configuration
-- Run this script in the Supabase SQL Editor to create all tables, buckets, and policies.
-- ==============================================================================

-- 1. Shops Table
CREATE TABLE IF NOT EXISTS public.shops (
    id TEXT PRIMARY KEY, -- Shop phone number or UUID
    phone TEXT NOT NULL UNIQUE,
    shop_name TEXT NOT NULL,
    password_hash TEXT,
    location TEXT,
    is_subscribed BOOLEAN DEFAULT FALSE,
    trial_start_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tickets Table
CREATE TABLE IF NOT EXISTS public.tickets (
    id TEXT PRIMARY KEY,
    ticket_number TEXT NOT NULL UNIQUE,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    device_model TEXT NOT NULL,
    device_type TEXT NOT NULL, -- mobile, laptop, watch, home, other
    issue_description TEXT NOT NULL,
    estimated_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    deposit NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    remaining_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    parts_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    parts_description TEXT,
    labor_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    net_profit NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'inDiagnosis', -- inDiagnosis, waitingForPart, readyForPickup, delivered
    shelf_location TEXT,
    internal_notes TEXT,
    shop_name TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Status History Table
CREATE TABLE IF NOT EXISTS public.status_history (
    id BIGSERIAL PRIMARY KEY,
    ticket_id TEXT NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    note TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_history ENABLE ROW LEVEL SECURITY;

-- Allow public read/write for tickets (Public tracking & workshop operations)
CREATE POLICY "Public read for tracking" ON public.tickets FOR SELECT USING (true);
CREATE POLICY "Public write for tickets" ON public.tickets FOR ALL USING (true);

CREATE POLICY "Public read status_history" ON public.status_history FOR SELECT USING (true);
CREATE POLICY "Public write status_history" ON public.status_history FOR ALL USING (true);

CREATE POLICY "Public read shops" ON public.shops FOR SELECT USING (true);
CREATE POLICY "Public write shops" ON public.shops FOR ALL USING (true);

-- Enable realtime streaming for tickets
ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;

-- ==============================================================================
-- 5. Supabase Storage: Ticket Device Intake Photos
-- ==============================================================================

-- Create public storage bucket for ticket inspection photos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('ticket-images', 'ticket-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow public access to view images (so customers can view device intake photos in tracking portal)
CREATE POLICY "Public Access ticket-images"
ON storage.objects FOR SELECT
USING (bucket_id = 'ticket-images');

-- Allow inserting/uploading device inspection images
CREATE POLICY "Public Upload ticket-images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'ticket-images');

-- Allow updating images
CREATE POLICY "Public Update ticket-images"
ON storage.objects FOR UPDATE
USING (bucket_id = 'ticket-images');

-- Allow deleting images
CREATE POLICY "Public Delete ticket-images"
ON storage.objects FOR DELETE
USING (bucket_id = 'ticket-images');

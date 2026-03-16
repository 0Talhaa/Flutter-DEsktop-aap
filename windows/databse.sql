-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  action_type character varying NOT NULL,
  entity_type character varying NOT NULL,
  entity_id uuid,
  old_values jsonb,
  new_values jsonb,
  ip_address character varying,
  user_agent text,
  description text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.customer_addresses (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  customer_id uuid NOT NULL,
  address_type character varying CHECK (address_type::text = ANY (ARRAY['home'::character varying, 'work'::character varying, 'other'::character varying]::text[])),
  address_line1 character varying NOT NULL,
  address_line2 character varying,
  city character varying NOT NULL,
  state character varying,
  postal_code character varying,
  country character varying DEFAULT 'PK'::character varying,
  latitude numeric,
  longitude numeric,
  is_default boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT customer_addresses_pkey PRIMARY KEY (id),
  CONSTRAINT customer_addresses_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id)
);
CREATE TABLE public.deal_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  deal_id uuid NOT NULL,
  menu_item_id uuid NOT NULL,
  required_quantity integer DEFAULT 1,
  free_quantity integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT deal_items_pkey PRIMARY KEY (id),
  CONSTRAINT deal_items_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id),
  CONSTRAINT deal_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id)
);
CREATE TABLE public.deal_usage_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  deal_id uuid NOT NULL,
  order_id uuid NOT NULL,
  customer_id uuid,
  discount_applied numeric NOT NULL,
  used_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT deal_usage_logs_pkey PRIMARY KEY (id),
  CONSTRAINT deal_usage_logs_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deals(id),
  CONSTRAINT deal_usage_logs_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT deal_usage_logs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id)
);
CREATE TABLE public.deals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  deal_name character varying NOT NULL,
  description text,
  deal_type character varying CHECK (deal_type::text = ANY (ARRAY['percentage'::character varying, 'fixed_amount'::character varying, 'buy_x_get_y'::character varying, 'bundle'::character varying]::text[])),
  discount_percentage numeric,
  discount_amount numeric,
  minimum_order_amount numeric,
  maximum_discount numeric,
  start_date timestamp without time zone NOT NULL,
  end_date timestamp without time zone NOT NULL,
  is_active boolean DEFAULT true,
  usage_limit_per_customer integer,
  total_usage_limit integer,
  current_usage_count integer DEFAULT 0,
  applicable_days ARRAY,
  applicable_time_start time without time zone,
  applicable_time_end time without time zone,
  applicable_order_types ARRAY,
  coupon_code character varying UNIQUE,
  priority integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT deals_pkey PRIMARY KEY (id)
);
CREATE TABLE public.department_printers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  department_id uuid NOT NULL,
  printer_name character varying NOT NULL,
  printer_ip character varying,
  printer_type character varying CHECK (printer_type::text = ANY (ARRAY['thermal'::character varying, 'impact'::character varying, 'network'::character varying]::text[])),
  is_active boolean DEFAULT true,
  is_primary boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT department_printers_pkey PRIMARY KEY (id),
  CONSTRAINT department_printers_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id)
);
CREATE TABLE public.departments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  department_name character varying NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT departments_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ingredients (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  ingredient_name character varying NOT NULL,
  description text,
  unit_id uuid NOT NULL,
  current_stock numeric DEFAULT 0,
  minimum_stock numeric DEFAULT 0,
  maximum_stock numeric,
  reorder_point numeric,
  cost_per_unit numeric,
  supplier_info text,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ingredients_pkey PRIMARY KEY (id),
  CONSTRAINT ingredients_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id)
);
CREATE TABLE public.invoices (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  invoice_number character varying NOT NULL UNIQUE,
  order_id uuid NOT NULL UNIQUE,
  customer_name character varying NOT NULL,
  customer_address text,
  customer_phone character varying,
  customer_email character varying,
  subtotal numeric NOT NULL,
  tax_amount numeric NOT NULL,
  discount_amount numeric DEFAULT 0,
  total_amount numeric NOT NULL,
  invoice_date timestamp without time zone NOT NULL,
  due_date timestamp without time zone,
  payment_status character varying CHECK (payment_status::text = ANY (ARRAY['unpaid'::character varying, 'partially_paid'::character varying, 'paid'::character varying]::text[])),
  notes text,
  generated_by uuid,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT invoices_pkey PRIMARY KEY (id),
  CONSTRAINT invoices_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT invoices_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(id)
);
CREATE TABLE public.kot_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  kot_ticket_id uuid NOT NULL,
  order_item_id uuid NOT NULL,
  quantity integer NOT NULL,
  special_instructions text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT kot_items_pkey PRIMARY KEY (id),
  CONSTRAINT kot_items_kot_ticket_id_fkey FOREIGN KEY (kot_ticket_id) REFERENCES public.kot_tickets(id),
  CONSTRAINT kot_items_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(id)
);
CREATE TABLE public.kot_tickets (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL,
  department_id uuid NOT NULL,
  kot_number character varying NOT NULL UNIQUE,
  status character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])),
  print_count integer DEFAULT 0,
  printed_at timestamp without time zone,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  completed_at timestamp without time zone,
  CONSTRAINT kot_tickets_pkey PRIMARY KEY (id),
  CONSTRAINT kot_tickets_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT kot_tickets_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id)
);
CREATE TABLE public.menu_categories (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  category_name character varying NOT NULL,
  description text,
  image_url character varying,
  parent_category_id uuid,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT menu_categories_pkey PRIMARY KEY (id),
  CONSTRAINT menu_categories_parent_category_id_fkey FOREIGN KEY (parent_category_id) REFERENCES public.menu_categories(id)
);
CREATE TABLE public.menu_item_addon_mapping (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  menu_item_id uuid NOT NULL,
  addon_id uuid NOT NULL,
  is_required boolean DEFAULT false,
  max_quantity integer DEFAULT 1,
  CONSTRAINT menu_item_addon_mapping_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_addon_mapping_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT menu_item_addon_mapping_addon_id_fkey FOREIGN KEY (addon_id) REFERENCES public.menu_item_addons(id)
);
CREATE TABLE public.menu_item_addons (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  addon_name character varying NOT NULL,
  price numeric NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT menu_item_addons_pkey PRIMARY KEY (id)
);
CREATE TABLE public.menu_item_variants (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  menu_item_id uuid NOT NULL,
  variant_name character varying NOT NULL,
  price_adjustment numeric DEFAULT 0,
  is_default boolean DEFAULT false,
  is_available boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT menu_item_variants_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_variants_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id)
);
CREATE TABLE public.menu_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  item_name character varying NOT NULL,
  description text,
  category_id uuid,
  department_id uuid,
  base_price numeric NOT NULL,
  preparation_time integer,
  image_url character varying,
  is_available boolean DEFAULT true,
  is_vegetarian boolean DEFAULT false,
  is_vegan boolean DEFAULT false,
  allergen_info text,
  calories integer,
  spice_level integer CHECK (spice_level >= 0 AND spice_level <= 5),
  sort_order integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT menu_items_pkey PRIMARY KEY (id),
  CONSTRAINT menu_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.menu_categories(id),
  CONSTRAINT menu_items_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  notification_type character varying CHECK (notification_type::text = ANY (ARRAY['order_update'::character varying, 'low_stock'::character varying, 'rider_assigned'::character varying, 'payment_received'::character varying, 'system_alert'::character varying]::text[])),
  title character varying NOT NULL,
  message text NOT NULL,
  data jsonb,
  is_read boolean DEFAULT false,
  read_at timestamp without time zone,
  channel character varying CHECK (channel::text = ANY (ARRAY['in_app'::character varying, 'email'::character varying, 'sms'::character varying, 'push'::character varying]::text[])),
  sent_at timestamp without time zone,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.order_deliveries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL UNIQUE,
  rider_id uuid,
  delivery_address text NOT NULL,
  delivery_latitude numeric,
  delivery_longitude numeric,
  delivery_distance numeric,
  estimated_delivery_time timestamp without time zone,
  actual_delivery_time timestamp without time zone,
  delivery_status character varying CHECK (delivery_status::text = ANY (ARRAY['pending'::character varying, 'assigned'::character varying, 'picked_up'::character varying, 'in_transit'::character varying, 'delivered'::character varying, 'failed'::character varying]::text[])),
  picked_up_at timestamp without time zone,
  delivered_at timestamp without time zone,
  delivery_proof_url character varying,
  customer_signature text,
  delivery_notes text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT order_deliveries_pkey PRIMARY KEY (id),
  CONSTRAINT order_deliveries_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_deliveries_rider_id_fkey FOREIGN KEY (rider_id) REFERENCES public.riders(id)
);
CREATE TABLE public.order_item_addons (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_item_id uuid NOT NULL,
  addon_id uuid NOT NULL,
  quantity integer DEFAULT 1,
  price numeric NOT NULL,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT order_item_addons_pkey PRIMARY KEY (id),
  CONSTRAINT order_item_addons_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(id),
  CONSTRAINT order_item_addons_addon_id_fkey FOREIGN KEY (addon_id) REFERENCES public.menu_item_addons(id)
);
CREATE TABLE public.order_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL,
  menu_item_id uuid NOT NULL,
  variant_id uuid,
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  discount_amount numeric DEFAULT 0,
  total_price numeric NOT NULL,
  special_instructions text,
  status character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'preparing'::character varying, 'ready'::character varying, 'served'::character varying, 'cancelled'::character varying]::text[])),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.menu_item_variants(id)
);
CREATE TABLE public.order_sources (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  source_name character varying NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT order_sources_pkey PRIMARY KEY (id)
);
CREATE TABLE public.order_status_history (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL,
  old_status character varying,
  new_status character varying NOT NULL,
  changed_by uuid,
  notes text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT order_status_history_pkey PRIMARY KEY (id),
  CONSTRAINT order_status_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id)
);
CREATE TABLE public.orders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_number character varying NOT NULL UNIQUE,
  customer_id uuid,
  customer_name character varying,
  customer_phone character varying,
  customer_email character varying,
  order_source_id uuid,
  order_type character varying CHECK (order_type::text = ANY (ARRAY['dine_in'::character varying, 'takeaway'::character varying, 'delivery'::character varying]::text[])),
  table_id uuid,
  status character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'preparing'::character varying, 'ready'::character varying, 'dispatched'::character varying, 'delivered'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])),
  subtotal numeric NOT NULL,
  tax_amount numeric DEFAULT 0,
  discount_amount numeric DEFAULT 0,
  delivery_charges numeric DEFAULT 0,
  total_amount numeric NOT NULL,
  special_instructions text,
  created_by uuid,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  confirmed_at timestamp without time zone,
  completed_at timestamp without time zone,
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id),
  CONSTRAINT orders_order_source_id_fkey FOREIGN KEY (order_source_id) REFERENCES public.order_sources(id),
  CONSTRAINT orders_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id),
  CONSTRAINT orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.payment_methods (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  method_name character varying NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  requires_verification boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT payment_methods_pkey PRIMARY KEY (id)
);
CREATE TABLE public.payments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  order_id uuid NOT NULL,
  payment_method_id uuid NOT NULL,
  amount numeric NOT NULL,
  transaction_id character varying UNIQUE,
  payment_status character varying CHECK (payment_status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying, 'refunded'::character varying]::text[])),
  gateway_response jsonb,
  paid_at timestamp without time zone,
  refunded_at timestamp without time zone,
  refund_amount numeric,
  refund_reason text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id)
);
CREATE TABLE public.permissions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  permission_name character varying NOT NULL UNIQUE,
  resource character varying NOT NULL,
  action character varying NOT NULL,
  description text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.purchase_order_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  purchase_order_id uuid NOT NULL,
  ingredient_id uuid NOT NULL,
  quantity_ordered numeric NOT NULL,
  quantity_received numeric DEFAULT 0,
  unit_id uuid NOT NULL,
  cost_per_unit numeric NOT NULL,
  total_cost numeric NOT NULL,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT purchase_order_items_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_order_items_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id),
  CONSTRAINT purchase_order_items_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id),
  CONSTRAINT purchase_order_items_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id)
);
CREATE TABLE public.purchase_orders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  po_number character varying NOT NULL UNIQUE,
  supplier_name character varying NOT NULL,
  supplier_contact character varying,
  order_date date NOT NULL,
  expected_delivery_date date,
  actual_delivery_date date,
  status character varying CHECK (status::text = ANY (ARRAY['pending'::character varying, 'received'::character varying, 'cancelled'::character varying]::text[])),
  total_amount numeric,
  notes text,
  created_by uuid,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT purchase_orders_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.recipes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  menu_item_id uuid NOT NULL,
  ingredient_id uuid NOT NULL,
  quantity_required numeric NOT NULL,
  unit_id uuid NOT NULL,
  notes text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT recipes_pkey PRIMARY KEY (id),
  CONSTRAINT recipes_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id),
  CONSTRAINT recipes_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id),
  CONSTRAINT recipes_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id)
);
CREATE TABLE public.rider_location_history (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  rider_id uuid NOT NULL,
  order_delivery_id uuid,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  accuracy numeric,
  speed numeric,
  bearing numeric,
  recorded_at timestamp without time zone NOT NULL,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT rider_location_history_pkey PRIMARY KEY (id),
  CONSTRAINT rider_location_history_rider_id_fkey FOREIGN KEY (rider_id) REFERENCES public.riders(id),
  CONSTRAINT rider_location_history_order_delivery_id_fkey FOREIGN KEY (order_delivery_id) REFERENCES public.order_deliveries(id)
);
CREATE TABLE public.riders (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  rider_code character varying NOT NULL UNIQUE,
  vehicle_type character varying CHECK (vehicle_type::text = ANY (ARRAY['bike'::character varying, 'scooter'::character varying, 'car'::character varying, 'bicycle'::character varying]::text[])),
  vehicle_number character varying,
  license_number character varying,
  current_status character varying CHECK (current_status::text = ANY (ARRAY['available'::character varying, 'busy'::character varying, 'offline'::character varying]::text[])),
  current_latitude numeric,
  current_longitude numeric,
  last_location_update timestamp without time zone,
  rating numeric DEFAULT 5.00,
  total_deliveries integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT riders_pkey PRIMARY KEY (id),
  CONSTRAINT riders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.role_permissions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id)
);
CREATE TABLE public.roles (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  role_name character varying NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.stock_movements (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  ingredient_id uuid NOT NULL,
  movement_type character varying NOT NULL CHECK (movement_type::text = ANY (ARRAY['stock_in'::character varying, 'stock_out'::character varying, 'wastage'::character varying, 'adjustment'::character varying]::text[])),
  quantity numeric NOT NULL,
  unit_id uuid NOT NULL,
  reference_type character varying,
  reference_id uuid,
  cost_per_unit numeric,
  total_cost numeric,
  reason text,
  performed_by uuid,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT stock_movements_pkey PRIMARY KEY (id),
  CONSTRAINT stock_movements_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES public.ingredients(id),
  CONSTRAINT stock_movements_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id),
  CONSTRAINT stock_movements_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.users(id)
);
CREATE TABLE public.system_settings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  setting_key character varying NOT NULL UNIQUE,
  setting_value text,
  data_type character varying CHECK (data_type::text = ANY (ARRAY['string'::character varying, 'number'::character varying, 'boolean'::character varying, 'json'::character varying]::text[])),
  description text,
  is_public boolean DEFAULT false,
  updated_by uuid,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT system_settings_pkey PRIMARY KEY (id),
  CONSTRAINT system_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id)
);
CREATE TABLE public.tables (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  table_number character varying NOT NULL UNIQUE,
  seating_capacity integer,
  location character varying,
  is_available boolean DEFAULT true,
  qr_code character varying UNIQUE,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT tables_pkey PRIMARY KEY (id)
);
CREATE TABLE public.units (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  unit_name character varying NOT NULL UNIQUE,
  unit_symbol character varying NOT NULL,
  unit_type character varying CHECK (unit_type::text = ANY (ARRAY['weight'::character varying, 'volume'::character varying, 'count'::character varying]::text[])),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT units_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_roles (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  assigned_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  assigned_by uuid,
  CONSTRAINT user_roles_pkey PRIMARY KEY (id),
  CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  email character varying NOT NULL UNIQUE,
  phone character varying UNIQUE,
  password_hash character varying NOT NULL,
  full_name character varying NOT NULL,
  user_type character varying NOT NULL CHECK (user_type::text = ANY (ARRAY['admin'::character varying, 'staff'::character varying, 'rider'::character varying, 'customer'::character varying]::text[])),
  is_active boolean DEFAULT true,
  email_verified boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  last_login_at timestamp without time zone,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
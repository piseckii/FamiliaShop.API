// ===== API CLIENT =====
const API_BASE = '/api';

const api = {
  async request(method, url, body = null) {
    const opts = {
      method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(API_BASE + url, opts);
    if (!res.ok) {
      const err = await res.json().catch(() => ({ message: 'Ошибка сервера' }));
      throw new Error(err.message || `HTTP ${res.status}`);
    }
    if (res.status === 204) return null;
    return res.json();
  },

  // Products
  products: {
    getAll: (params = {}) => {
      const q = new URLSearchParams();
      Object.entries(params).forEach(([k, v]) => { if (v !== null && v !== '' && v !== undefined) q.append(k, v); });
      return api.request('GET', `/products${q.toString() ? '?' + q : ''}`);
    },
    getById: (id) => api.request('GET', `/products/${id}`),
    create: (data) => api.request('POST', '/products', data),
    update: (id, data) => api.request('PUT', `/products/${id}`, data),
    delete: (id) => api.request('DELETE', `/products/${id}`),
    // Статистика из v_РейтингТоваров (оценки, продажи, выручка)
    getStats: () => api.request('GET', '/products/stats'),
  },

  // Buyers
  buyers: {
    getAll: () => api.request('GET', '/buyers'),
    getById: (id) => api.request('GET', `/buyers/${id}`),
    getByEmail: (email) => api.request('GET', `/buyers/email/${encodeURIComponent(email)}`),
    create: (data) => api.request('POST', '/buyers', data),
    update: (id, data) => api.request('PUT', `/buyers/${id}`, data),
    delete: (id) => api.request('DELETE', `/buyers/${id}`),
    getAddresses: (id) => api.request('GET', `/buyers/${id}/addresses`),
    addAddress: (data) => api.request('POST', '/buyers/addresses', data),
    getOrders: (id) => api.request('GET', `/buyers/${id}/orders`),
  },

  // Orders
  orders: {
    getAll: (status = null) => api.request('GET', `/orders${status ? `?status=${status}` : ''}`),
    getById: (id) => api.request('GET', `/orders/${id}`),
    // Создание через sp_ОформитьЗаказ — товары берутся из корзины в БД
    create: (data) => api.request('POST', '/orders', data),
    updateStatus: (id, status) => api.request('PATCH', `/orders/${id}/status`, { status }),
    // История смены статусов из ЛогСтатусовЗаказа (заполняется триггером)
    getLog: (id) => api.request('GET', `/orders/${id}/log`),
  },

  // Cart
  cart: {
    get: (buyerId) => api.request('GET', `/cart/${buyerId}`),
    addItem: (buyerId, data) => api.request('POST', `/cart/${buyerId}/items`, data),
    updateItem: (buyerId, tovarId, qty) => api.request('PUT', `/cart/${buyerId}/items/${tovarId}`, { kolichestvo: qty }),
    removeItem: (buyerId, tovarId) => api.request('DELETE', `/cart/${buyerId}/items/${tovarId}`),
    clear: (buyerId) => api.request('DELETE', `/cart/${buyerId}`),
  },

  // Reviews
  reviews: {
    byProduct: (id) => api.request('GET', `/reviews/product/${id}`),
    byBuyer: (id) => api.request('GET', `/reviews/buyer/${id}`),
    create: (data) => api.request('POST', '/reviews', data),
    delete: (id) => api.request('DELETE', `/reviews/${id}`),
  },

  // Coupons
  coupons: {
    getAll: () => api.request('GET', '/coupons'),
    validate: (code) => api.request('GET', `/coupons/validate/${encodeURIComponent(code)}`),
    create: (data) => api.request('POST', '/coupons', data),
    delete: (id) => api.request('DELETE', `/coupons/${id}`),
  },

  // Discounts
  discounts: {
    getAll: () => api.request('GET', '/discounts'),
    create: (data) => api.request('POST', '/discounts', data),
    delete: (id) => api.request('DELETE', `/discounts/${id}`),
  },

  // References
  refs: {
    brands: () => api.request('GET', '/references/brands'),
    createBrand: (data) => api.request('POST', '/references/brands', data),
    deleteBrand: (id) => api.request('DELETE', `/references/brands/${id}`),
    sizes: () => api.request('GET', '/references/sizes'),
    createSize: (data) => api.request('POST', '/references/sizes', data),
    categories: () => api.request('GET', '/references/categories'),
    createCategory: (data) => api.request('POST', '/references/categories', data),
    deleteCategory: (id) => api.request('DELETE', `/references/categories/${id}`),
    deliveryMethods: () => api.request('GET', '/references/delivery-methods'),
    paymentMethods: () => api.request('GET', '/references/payment-methods'),
  },
};

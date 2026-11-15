// ===== GLOBAL STATE =====
const App = {
  currentUser: null,
  cart: [],
  
  init() {
    const saved = sessionStorage.getItem('familia_user');
    if (saved) {
      try { this.currentUser = JSON.parse(saved); } catch {}
    }
    this.updateCartBadge();
  },

  setUser(user) {
    this.currentUser = user;
    sessionStorage.setItem('familia_user', JSON.stringify(user));
  },

  logout() {
    this.currentUser = null;
    this.cart = [];
    sessionStorage.removeItem('familia_user');
    this.updateCartBadge();
    window.location.href = '/index.html';
  },

  async loadCart() {
    if (!this.currentUser) { this.cart = []; return; }
    try {
      this.cart = await api.cart.get(this.currentUser.kod_pokupatelya);
      this.updateCartBadge();
    } catch { this.cart = []; }
  },

  async addToCart(product) {
    if (!this.currentUser) {
      Toast.show('Войдите в аккаунт, чтобы добавить в корзину', 'error');
      return;
    }
    try {
      await api.cart.addItem(this.currentUser.kod_pokupatelya, {
        kod_tovara: product.kod_tovara,
        kolichestvo: 1
      });
      await this.loadCart();
      Toast.show(`${product.naimenovanie} добавлен в корзину`, 'success');
    } catch (e) {
      Toast.show(e.message, 'error');
    }
  },

  getCartTotal() {
    return this.cart.reduce((sum, item) => sum + item.cena * item.kolichestvo, 0);
  },

  updateCartBadge() {
    const badge = document.getElementById('cartBadge');
    const total = this.cart.reduce((sum, i) => sum + i.kolichestvo, 0);
    if (badge) {
      badge.textContent = total;
      badge.classList.toggle('show', total > 0);
    }
  }
};

// ===== TOAST =====
const Toast = {
  container: null,
  
  init() {
    this.container = document.getElementById('toastContainer');
    if (!this.container) {
      this.container = document.createElement('div');
      this.container.id = 'toastContainer';
      this.container.className = 'toast-container';
      document.body.appendChild(this.container);
    }
  },

  show(msg, type = 'default', duration = 3000) {
    if (!this.container) this.init();
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    const icon = type === 'success' ? '✓' : type === 'error' ? '✕' : 'ℹ';
    el.innerHTML = `<span>${icon}</span><span>${msg}</span>`;
    this.container.appendChild(el);
    setTimeout(() => {
      el.style.opacity = '0';
      el.style.transform = 'translateX(100%)';
      el.style.transition = '0.3s ease';
      setTimeout(() => el.remove(), 300);
    }, duration);
  }
};

// ===== MODAL =====
const Modal = {
  open(id) {
    document.getElementById(id)?.classList.add('open');
    document.body.style.overflow = 'hidden';
  },
  close(id) {
    document.getElementById(id)?.classList.remove('open');
    document.body.style.overflow = '';
  }
};

// ===== CART SIDEBAR =====
const CartSidebar = {
  open() {
    document.getElementById('cartOverlay')?.classList.add('open');
    document.getElementById('cartSidebar')?.classList.add('open');
    document.body.style.overflow = 'hidden';
    this.render();
  },
  close() {
    document.getElementById('cartOverlay')?.classList.remove('open');
    document.getElementById('cartSidebar')?.classList.remove('open');
    document.body.style.overflow = '';
  },

  async render() {
    const itemsEl = document.getElementById('cartItems');
    const totalEl = document.getElementById('cartTotal');
    if (!itemsEl) return;

    if (!App.currentUser) {
      itemsEl.innerHTML = `<div class="empty-state"><div class="empty-state-icon">🛒</div><h3>Корзина пуста</h3><p>Войдите в аккаунт</p></div>`;
      if (totalEl) totalEl.textContent = '0 ₽';
      return;
    }

    await App.loadCart();
    const cart = App.cart;

    if (!cart.length) {
      itemsEl.innerHTML = `<div class="empty-state"><div class="empty-state-icon">🛒</div><h3>Корзина пуста</h3><p>Добавьте товары из каталога</p></div>`;
      if (totalEl) totalEl.textContent = '0 ₽';
      return;
    }

    itemsEl.innerHTML = cart.map(item => `
      <div class="cart-item" data-id="${item.kod_tovara}">
        <div class="cart-item-img">👕</div>
        <div class="cart-item-info">
          <div class="cart-item-brand">${item.brand || ''}</div>
          <div class="cart-item-name">${item.naimenovanie}</div>
          <div class="cart-item-controls">
            <button class="qty-btn" onclick="CartSidebar.changeQty(${item.kod_tovara}, ${item.kolichestvo - 1})">−</button>
            <span class="qty-num">${item.kolichestvo}</span>
            <button class="qty-btn" onclick="CartSidebar.changeQty(${item.kod_tovara}, ${item.kolichestvo + 1})">+</button>
            <span class="cart-item-price">${fmt(item.cena * item.kolichestvo)}</span>
            <button class="cart-item-remove" onclick="CartSidebar.removeItem(${item.kod_tovara})">✕</button>
          </div>
        </div>
      </div>
    `).join('');

    if (totalEl) totalEl.textContent = fmt(App.getCartTotal());
  },

  async changeQty(tovarId, qty) {
    if (!App.currentUser) return;
    try {
      await api.cart.updateItem(App.currentUser.kod_pokupatelya, tovarId, qty);
      await this.render();
    } catch (e) { Toast.show(e.message, 'error'); }
  },

  async removeItem(tovarId) {
    if (!App.currentUser) return;
    try {
      await api.cart.removeItem(App.currentUser.kod_pokupatelya, tovarId);
      await this.render();
      Toast.show('Товар удалён из корзины');
    } catch (e) { Toast.show(e.message, 'error'); }
  },

  goToCheckout() {
    if (!App.cart.length) { Toast.show('Корзина пуста', 'error'); return; }
    this.close();
    window.location.href = '/pages/checkout.html';
  }
};

// ===== HELPERS =====
function fmt(n) {
  return new Intl.NumberFormat('ru-RU', { style: 'currency', currency: 'RUB', maximumFractionDigits: 0 }).format(n || 0);
}

function fmtDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('ru-RU', { day: '2-digit', month: 'short', year: 'numeric' });
}

function stars(n) {
  const full = Math.round(n || 0);
  return '★'.repeat(full) + '☆'.repeat(5 - full);
}

function statusBadge(status) {
  if (!status) return '—';
  const clean = status.trim();
  const cls = clean.replace(/\s/g, '_');
  return `<span class="status-badge status-${cls}">${clean}</span>`;
}

// ===== ВАЛИДАЦИЯ И МАСКА ТЕЛЕФОНА =====

function maskPhone(input) {
    let val = input.value.replace(/\D/g, '');
    if (val.length === 0) {
        input.value = '';
        return;
    }
    let formatted = '+7';
    if (val.length > 1) {
        formatted += ' (' + val.substring(1, 4);
    }
    if (val.length >= 5) {
        formatted += ') ' + val.substring(4, 7);
    }
    if (val.length >= 8) {
        formatted += '-' + val.substring(7, 9);
    }
    if (val.length >= 10) {
        formatted += '-' + val.substring(9, 11);
    }
    input.value = formatted;
}

function setupPhoneMask(selector) {
    document.querySelectorAll(selector).forEach(input => {
        input.addEventListener('input', function () {
            maskPhone(this);
        });
        input.addEventListener('focus', function () {
            if (!this.value) {
                this.value = '+7';
            }
        });
        input.addEventListener('blur', function () {
            if (this.value === '+7') {
                this.value = '';
            }
        });
    });
}

function isValidPhone(phone) {
    const digits = phone.replace(/\D/g, '');
    return digits.length === 11 && digits.startsWith('7');
}

function validateForm(form) {
    let isValid = true;
    const fields = form.querySelectorAll('[data-validate]');
    fields.forEach(field => {
        const value = field.value.trim();
        const rules = field.dataset.validate.split(',').map(r => r.trim());
        let errorMsg = '';
        rules.forEach(rule => {
            if (rule === 'required' && !value) {
                errorMsg = 'Обязательное поле';
            }
            if (rule === 'email' && value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
                errorMsg = 'Введите корректный email';
            }
            if (rule === 'phone' && value && !isValidPhone(value)) {
                errorMsg = 'Введите номер в формате +7 (999) 999-99-99';
            }
            if (rule.startsWith('min:')) {
                const min = parseFloat(rule.split(':')[1]);
                if (value && parseFloat(value) < min) {
                    errorMsg = `Значение не может быть меньше ${min}`;
                }
            }
            if (rule.startsWith('max:')) {
                const max = parseFloat(rule.split(':')[1]);
                if (value && parseFloat(value) > max) {
                    errorMsg = `Значение не может быть больше ${max}`;
                }
            }
            if (rule === 'positive') {
                if (value && parseFloat(value) <= 0) {
                    errorMsg = 'Значение должно быть больше 0';
                }
            }
            if (rule === 'dateRange') {
                const container = field.closest('form') || field.closest('.modal-body');
                if (container) {
                    const startField = container.querySelector('[data-validate*="dateStart"]');
                    const endField = container.querySelector('[data-validate*="dateEnd"]');
                    if (startField && endField) {
                        const start = new Date(startField.value);
                        const end = new Date(endField.value);
                        if (start && end && end < start) {
                            errorMsg = 'Дата окончания должна быть позже даты начала';
                        }
                    }
                }
            }
        });
        const errorContainer = field.parentElement.querySelector('.field-error');
        if (errorContainer) {
            errorContainer.textContent = errorMsg;
            errorContainer.style.display = errorMsg ? 'block' : 'none';
            field.classList.toggle('error', !!errorMsg);
        }
        if (errorMsg) isValid = false;
    });
    return isValid;
}

// ===== HEADER RENDER =====
function renderHeader() {
  const headerEl = document.getElementById('appHeader');
  if (!headerEl) return;

  const page = window.location.pathname;
  const navLinks = [
    { href: '/index.html', label: 'Главная' },
    { href: '/pages/catalog.html', label: 'Каталог' },
  ];
  if (App.currentUser) {
    navLinks.push({ href: '/pages/cabinet.html', label: 'Кабинет' });
  }

  const cartCount = App.cart.reduce((s, i) => s + i.kolichestvo, 0);

  headerEl.innerHTML = `
    <div class="header-inner">
      <a href="/index.html" class="logo">FAMILIA<span>SHOP</span></a>
      <nav class="nav">
        ${navLinks.map(l => `<a href="${l.href}" class="${page.endsWith(l.href.replace('/', '')) || (l.href === '/index.html' && page === '/') ? 'active' : ''}">${l.label}</a>`).join('')}
      </nav>
      <div class="search-wrap">
        <span class="search-icon">🔍</span>
        <input class="search-input" id="globalSearch" placeholder="Поиск товаров..." 
               onkeydown="if(event.key==='Enter'){window.location='/pages/catalog.html?search='+encodeURIComponent(this.value)}">
      </div>
      <div class="header-actions">
        <button class="btn-icon" onclick="CartSidebar.open()" title="Корзина">
          🛒<span id="cartBadge" class="cart-badge ${cartCount > 0 ? 'show' : ''}">${cartCount}</span>
        </button>
        ${App.currentUser
          ? `<button class="btn btn-outline btn-sm" onclick="App.logout()">Выйти</button>`
          : `<button class="btn btn-primary btn-sm" onclick="Modal.open('loginModal')">Войти</button>`
        }
      </div>
    </div>
  `;
}

// ===== LOGIN MODAL =====
function renderLoginModal() {
  const existing = document.getElementById('loginModal');
  if (existing) return;

  const el = document.createElement('div');
  el.id = 'loginModal';
  el.className = 'modal-overlay';
  el.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2>Войти / Зарегистрироваться</h2>
        <button class="modal-close" onclick="Modal.close('loginModal')">✕</button>
      </div>
      <div class="modal-body">
        <div class="tabs">
          <button class="tab-btn active" onclick="switchTab(this,'loginTab')">Войти</button>
          <button class="tab-btn" onclick="switchTab(this,'registerTab')">Регистрация</button>
        </div>
        
        <div id="loginTab" class="tab-content active">
          <div class="form-group">
            <label class="form-label">Email</label>
            <input class="form-input" id="loginEmail" type="email" placeholder="your@email.com" data-validate="required,email">
            <div class="field-error"></div>
            <div class="field-hint" style="font-size:0.75rem;color:var(--mid);margin-top:4px;">
              Допустимы латинские буквы, цифры, точки, дефис, подчёркивание, @ и точка в домене
            </div>
          </div>
          <button class="btn btn-primary btn-full btn-lg" onclick="doLogin()">Войти</button>
        </div>
        
        <div id="registerTab" class="tab-content">
          <div class="form-group">
            <label class="form-label">Имя</label>
            <input class="form-input" id="regName" placeholder="Иван Иванов" data-validate="required">
            <div class="field-error"></div>
          </div>
          <div class="form-group">
            <label class="form-label">Email</label>
            <input class="form-input" id="regEmail" type="email" placeholder="your@email.com" data-validate="required,email">
            <div class="field-error"></div>
            <div class="field-hint" style="font-size:0.75rem;color:var(--mid);margin-top:4px;">
              Допустимы латинские буквы, цифры, точки, дефис, подчёркивание, @ и точка в домене
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">Телефон</label>
            <input class="form-input phone-mask" id="regPhone" placeholder="+7 (999) 999-99-99" data-validate="phone">
            <div class="field-error"></div>
          </div>
          <button class="btn btn-accent btn-full btn-lg" onclick="doRegister()">Создать аккаунт</button>
        </div>
      </div>
    </div>
  `;
  el.addEventListener('click', (e) => { if (e.target === el) Modal.close('loginModal'); });
  document.body.appendChild(el);
  setupPhoneMask('.phone-mask');
}

function switchTab(btn, tabId) {
  btn.closest('.tabs').querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  btn.closest('.modal-body').querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.getElementById(tabId)?.classList.add('active');
}

async function doLogin() {
  const form = document.getElementById('loginTab');
  if (!validateForm(form)) {
    Toast.show('Исправьте ошибки в форме', 'error');
    return;
  }
  const email = document.getElementById('loginEmail')?.value?.trim();
  if (!email) { Toast.show('Введите email', 'error'); return; }
  try {
    const user = await api.buyers.getByEmail(email);
    App.setUser(user);
    await App.loadCart();
    Modal.close('loginModal');
    renderHeader();
    Toast.show(`Добро пожаловать, ${user.imya}!`, 'success');
  } catch (e) {
    Toast.show('Пользователь не найден. Зарегистрируйтесь', 'error');
  }
}

async function doRegister() {
  const form = document.getElementById('registerTab');
  if (!validateForm(form)) {
    Toast.show('Исправьте ошибки в форме', 'error');
    return;
  }
  const name = document.getElementById('regName')?.value?.trim();
  const email = document.getElementById('regEmail')?.value?.trim();
  const phone = document.getElementById('regPhone')?.value?.trim() || null;
  if (!name || !email) { Toast.show('Заполните обязательные поля', 'error'); return; }
  try {
    const result = await api.buyers.create({ imya: name, email, telefon: phone });
    const user = await api.buyers.getById(result.id);
    App.setUser(user);
    await App.loadCart();
    Modal.close('loginModal');
    renderHeader();
    Toast.show(`Аккаунт создан! Добро пожаловать, ${user.imya}!`, 'success');
  } catch (e) {
    Toast.show(e.message, 'error');
  }
}

// ===== CART SIDEBAR HTML =====
function renderCartSidebarHtml() {
  const existing = document.getElementById('cartSidebar');
  if (existing) return;

  const overlay = document.createElement('div');
  overlay.id = 'cartOverlay';
  overlay.className = 'cart-overlay';
  overlay.onclick = () => CartSidebar.close();
  document.body.appendChild(overlay);

  const sidebar = document.createElement('div');
  sidebar.id = 'cartSidebar';
  sidebar.className = 'cart-sidebar';
  sidebar.innerHTML = `
    <div class="cart-header">
      <h3>Корзина</h3>
      <button class="btn-icon" onclick="CartSidebar.close()">✕</button>
    </div>
    <div class="cart-items" id="cartItems">
      <div class="loading-overlay"><div class="spinner"></div></div>
    </div>
    <div class="cart-footer">
      <div class="coupon-row">
        <input id="couponInput" class="form-input" placeholder="Промокод">
        <button class="btn btn-outline" onclick="applyCoupon()">Применить</button>
      </div>
      <div class="cart-total">
        <span>Итого</span>
        <span class="cart-total-sum" id="cartTotal">0 ₽</span>
      </div>
      <button class="btn btn-accent btn-full btn-lg" onclick="CartSidebar.goToCheckout()">
        Оформить заказ →
      </button>
    </div>
  `;
  document.body.appendChild(sidebar);
}

async function applyCoupon() {
  const code = document.getElementById('couponInput')?.value?.trim();
  if (!code) {
    Toast.show('Введите промокод', 'error');
    return;
  }
  try {
    const kupon = await api.coupons.validate(code);
    const label = kupon.tip_skidki === 'процентная'
      ? `−${kupon.razmer_skidki}%`
      : `−${fmt(kupon.razmer_skidki)}`;
    Toast.show(`Купон применён: ${label}`, 'success');
    sessionStorage.setItem('applied_coupon', JSON.stringify(kupon));
  } catch (e) {
    Toast.show(e.message, 'error');
    sessionStorage.removeItem('applied_coupon');
  }
}

// ===== INIT =====
document.addEventListener('DOMContentLoaded', async () => {
  Toast.init();
  App.init();
  renderLoginModal();
  renderCartSidebarHtml();
  if (App.currentUser) await App.loadCart();
  renderHeader();
  setupPhoneMask('.phone-mask');
});
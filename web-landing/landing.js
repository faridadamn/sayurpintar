// ===== NAVBAR SCROLL =====
const navbar = document.getElementById('navbar');
window.addEventListener('scroll', () => {
    navbar.classList.toggle('scrolled', window.scrollY > 50);
});

// ===== MOBILE NAV TOGGLE =====
const navToggle = document.getElementById('navToggle');
const navLinks = document.getElementById('navLinks');
navToggle.addEventListener('click', () => {
    navLinks.classList.toggle('open');
});
// Close on link click
navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => navLinks.classList.remove('open'));
});

// ===== SMOOTH SCROLL =====
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});

// ===== COUNTER ANIMATION =====
function animateCounters() {
    const counters = document.querySelectorAll('[data-count]');
    counters.forEach(counter => {
        if (counter.dataset.animated) return;
        const target = parseInt(counter.dataset.count);
        const duration = 2000;
        const start = performance.now();

        function update(currentTime) {
            const elapsed = currentTime - start;
            const progress = Math.min(elapsed / duration, 1);
            // Ease out cubic
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = Math.floor(eased * target);

            if (target >= 1000) {
                counter.textContent = current.toLocaleString('id-ID');
            } else {
                counter.textContent = current;
            }

            if (progress < 1) {
                requestAnimationFrame(update);
            } else {
                counter.dataset.animated = 'true';
            }
        }
        requestAnimationFrame(update);
    });
}

// Intersection Observer for counters
const counterObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            animateCounters();
        }
    });
}, { threshold: 0.5 });

const heroStats = document.querySelector('.hero-stats');
if (heroStats) counterObserver.observe(heroStats);

// ===== SCROLL REVEAL ANIMATION =====
const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('revealed');
            revealObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });

// Add reveal class to elements
const revealElements = document.querySelectorAll(
    '.pain-card, .feature-row, .more-feature-card, .step, .impact-card, ' +
    '.testimonial-card, .pricing-card, .faq-item, .cta-card'
);
revealElements.forEach(el => {
    el.classList.add('reveal');
    revealObserver.observe(el);
});

// Reveal CSS (injected)
const revealCSS = document.createElement('style');
revealCSS.textContent = `
    .reveal {
        opacity: 0;
        transform: translateY(30px);
        transition: opacity 0.6s ease, transform 0.6s ease;
    }
    .reveal.revealed {
        opacity: 1;
        transform: translateY(0);
    }
    .reveal:nth-child(2) { transition-delay: 0.1s; }
    .reveal:nth-child(3) { transition-delay: 0.2s; }
    .reveal:nth-child(4) { transition-delay: 0.3s; }
    .reveal:nth-child(5) { transition-delay: 0.4s; }
    .reveal:nth-child(6) { transition-delay: 0.5s; }
`;
document.head.appendChild(revealCSS);

// ===== FAQ ACCORDION =====
document.querySelectorAll('.faq-question').forEach(button => {
    button.addEventListener('click', () => {
        const item = button.parentElement;
        const isActive = item.classList.contains('active');

        // Close all
        document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('active'));

        // Open clicked (if wasn't active)
        if (!isActive) {
            item.classList.add('active');
        }
    });
});

// ===== PHONE MOCKUP PARALLAX =====
const phoneMockup = document.querySelector('.phone-mockup');
if (phoneMockup) {
    window.addEventListener('mousemove', (e) => {
        const x = (e.clientX / window.innerWidth - 0.5) * 10;
        const y = (e.clientY / window.innerHeight - 0.5) * 10;
        phoneMockup.style.transform = `rotate(3deg) perspective(1000px) rotateY(${x}deg) rotateX(${-y}deg)`;
    });
}

// ===== TYPING EFFECT FOR HERO BADGE =====
const heroBadge = document.querySelector('.hero-badge');
if (heroBadge) {
    heroBadge.style.opacity = '0';
    heroBadge.style.transform = 'translateY(10px)';
    setTimeout(() => {
        heroBadge.style.transition = 'all 0.6s ease';
        heroBadge.style.opacity = '1';
        heroBadge.style.transform = 'translateY(0)';
    }, 300);
}

// ===== STAGGER HERO ELEMENTS =====
const heroElements = [
    '.hero-badge', '.hero-title', '.hero-subtitle', '.hero-cta', '.hero-stats'
];
heroElements.forEach((selector, i) => {
    const el = document.querySelector(selector);
    if (el) {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        setTimeout(() => {
            el.style.transition = 'all 0.6s ease';
            el.style.opacity = '1';
            el.style.transform = 'translateY(0)';
        }, 400 + (i * 150));
    }
});

// ===== PHONE SCREEN ANIMATION =====
const phoneScreen = document.querySelector('.phone-screen');
if (phoneScreen) {
    const mockCards = phoneScreen.querySelectorAll('.mock-card');
    mockCards.forEach((card, i) => {
        card.style.opacity = '0';
        card.style.transform = 'translateX(20px)';
        setTimeout(() => {
            card.style.transition = 'all 0.5s ease';
            card.style.opacity = '1';
            card.style.transform = 'translateX(0)';
        }, 1200 + (i * 200));
    });
}

// ===== PRICING HOVER GLOW =====
document.querySelectorAll('.pricing-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        card.style.setProperty('--glow-x', `${x}px`);
        card.style.setProperty('--glow-y', `${y}px`);
    });
});

// Add glow effect CSS
const glowCSS = document.createElement('style');
glowCSS.textContent = `
    .pricing-card::before {
        content: '';
        position: absolute;
        top: 0; left: 0; right: 0; bottom: 0;
        border-radius: inherit;
        background: radial-gradient(
            400px circle at var(--glow-x, 50%) var(--glow-y, 50%),
            rgba(34, 197, 94, 0.06),
            transparent 60%
        );
        pointer-events: none;
        opacity: 0;
        transition: opacity 0.3s;
    }
    .pricing-card:hover::before {
        opacity: 1;
    }
    .pricing-card {
        position: relative;
        overflow: hidden;
    }
`;
document.head.appendChild(glowCSS);

// ===== RIPPLE EFFECT ON BUTTONS =====
document.querySelectorAll('.btn').forEach(btn => {
    btn.addEventListener('click', function(e) {
        const ripple = document.createElement('span');
        const rect = this.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;

        ripple.style.cssText = `
            position: absolute; width: ${size}px; height: ${size}px;
            left: ${x}px; top: ${y}px;
            background: rgba(255,255,255,0.3);
            border-radius: 50%;
            transform: scale(0);
            animation: ripple 0.6s ease-out;
            pointer-events: none;
        `;
        this.style.position = 'relative';
        this.style.overflow = 'hidden';
        this.appendChild(ripple);
        setTimeout(() => ripple.remove(), 600);
    });
});

const rippleCSS = document.createElement('style');
rippleCSS.textContent = `
    @keyframes ripple {
        to { transform: scale(4); opacity: 0; }
    }
`;
document.head.appendChild(rippleCSS);

// ===== SMOOTH NUMBER FORMATTING =====
function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(0) + 'K';
    return num.toString();
}

// ===== INTERSECTION FOR IMPACT NUMBERS =====
const impactNumbers = document.querySelectorAll('.impact-number');
const impactObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.animation = 'countUp 0.8s ease forwards';
            impactObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.5 });
impactNumbers.forEach(el => impactObserver.observe(el));

const impactCSS = document.createElement('style');
impactCSS.textContent = `
    @keyframes countUp {
        from { opacity: 0; transform: translateY(20px) scale(0.8); }
        to { opacity: 1; transform: translateY(0) scale(1); }
    }
`;
document.head.appendChild(impactCSS);

// ===== CONSOLE EASTER EGG =====
console.log('%c🥬 SayurPintar', 'font-size: 24px; font-weight: bold; color: #22c55e;');
console.log('%cDibuat dengan ❤️ untuk tukang sayur Indonesia', 'font-size: 14px; color: #6b7280;');

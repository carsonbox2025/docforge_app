/**
 * DocForge — Landing Page Scripts
 * Scroll animations, theme toggle, mobile menu, counter animation
 */
(function () {
  'use strict';

  // ============================================================
  // DOM references
  // ============================================================
  const navbar = document.getElementById('navbar');
  const themeToggle = document.getElementById('themeToggle');
  const mobileMenuToggle = document.getElementById('mobileMenuToggle');
  const mobileDrawer = document.getElementById('mobileDrawer');
  const html = document.documentElement;

  // ============================================================
  // Navbar scroll effect
  // ============================================================
  function updateNavbar() {
    const scrolled = window.scrollY > 20;
    navbar.classList.toggle('scrolled', scrolled);
  }
  window.addEventListener('scroll', updateNavbar, { passive: true });
  updateNavbar(); // init

  // ============================================================
  // Theme toggle (light / dark)
  // ============================================================
  function getPreferredTheme() {
    const stored = localStorage.getItem('docforge-theme');
    if (stored) return stored;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function applyTheme(theme) {
    html.setAttribute('data-theme', theme);
    localStorage.setItem('docforge-theme', theme);
  }

  function toggleTheme() {
    const current = html.getAttribute('data-theme');
    applyTheme(current === 'dark' ? 'light' : 'dark');
  }

  applyTheme(getPreferredTheme());
  themeToggle.addEventListener('click', toggleTheme);

  // Listen for system preference changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    if (!localStorage.getItem('docforge-theme')) {
      applyTheme(e.matches ? 'dark' : 'light');
    }
  });

  // ============================================================
  // Mobile menu
  // ============================================================
  function openDrawer() {
    mobileDrawer.classList.add('open');
    mobileDrawer.setAttribute('aria-hidden', 'false');
    mobileMenuToggle.classList.add('active');
    mobileMenuToggle.setAttribute('aria-label', '关闭菜单');
    mobileMenuToggle.setAttribute('aria-expanded', 'true');
  }

  function closeDrawer() {
    mobileDrawer.classList.remove('open');
    mobileDrawer.setAttribute('aria-hidden', 'true');
    mobileMenuToggle.classList.remove('active');
    mobileMenuToggle.setAttribute('aria-label', '打开菜单');
    mobileMenuToggle.setAttribute('aria-expanded', 'false');
  }

  mobileMenuToggle.addEventListener('click', function () {
    if (mobileDrawer.classList.contains('open')) {
      closeDrawer();
    } else {
      openDrawer();
    }
  });

  // Close drawer when a mobile nav link is clicked
  mobileDrawer.querySelectorAll('.mobile-nav-link').forEach(function (link) {
    link.addEventListener('click', closeDrawer);
  });

  // Close drawer on Escape
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && mobileDrawer.classList.contains('open')) {
      closeDrawer();
      mobileMenuToggle.focus();
    }
  });

  // Close drawer when clicking outside
  document.addEventListener('click', function (e) {
    if (mobileDrawer.classList.contains('open') &&
        !mobileDrawer.contains(e.target) &&
        !mobileMenuToggle.contains(e.target)) {
      closeDrawer();
    }
  });

  // ============================================================
  // Scroll-triggered animations (Intersection Observer)
  // ============================================================
  function setupScrollAnimations() {
    // Only run if user hasn't requested reduced motion
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    var observerOptions = {
      root: null,
      rootMargin: '0px 0px -60px 0px',
      threshold: 0.1,
    };

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, observerOptions);

    // Observe elements with .animate-on-scroll class
    var targets = document.querySelectorAll('.animate-on-scroll');
    targets.forEach(function (el) {
      observer.observe(el);
    });

    // Also apply stagger classes to feature cards
    var featureCards = document.querySelectorAll('.feature-card');
    featureCards.forEach(function (card, i) {
      card.classList.add('animate-on-scroll', 'stagger-' + ((i % 3) + 1));
      observer.observe(card);
    });

    // Stagger step cards
    var stepCards = document.querySelectorAll('.step-card');
    stepCards.forEach(function (card, i) {
      card.classList.add('animate-on-scroll', 'stagger-' + ((i % 3) + 1));
      observer.observe(card);
    });

    // Observe section headers
    var sectionHeaders = document.querySelectorAll('.section-header');
    sectionHeaders.forEach(function (header) {
      header.classList.add('animate-on-scroll');
      observer.observe(header);
    });
  }

  // ============================================================
  // Counter animation for hero stats & trust bar
  // ============================================================
  function animateCounters() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    var counterObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;

        var el = entry.target;
        var target = parseInt(el.getAttribute('data-count'), 10);
        if (isNaN(target)) return;

        var duration = 1500;
        var startTime = null;
        var startVal = 0;

        function step(timestamp) {
          if (!startTime) startTime = timestamp;
          var progress = Math.min((timestamp - startTime) / duration, 1);
          // Ease-out curve
          var eased = 1 - Math.pow(1 - progress, 3);
          var current = Math.floor(startVal + (target - startVal) * eased);
          el.textContent = current.toLocaleString();

          if (progress < 1) {
            requestAnimationFrame(step);
          } else {
            el.textContent = target.toLocaleString();
          }
        }

        requestAnimationFrame(step);
        counterObserver.unobserve(el);
      });
    }, { threshold: 0.5 });

    document.querySelectorAll('[data-count]').forEach(function (el) {
      counterObserver.observe(el);
    });
  }

  // ============================================================
  // Smooth scroll for anchor links (respecting fixed navbar)
  // ============================================================
  function setupSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
      anchor.addEventListener('click', function (e) {
        var href = this.getAttribute('href');
        if (href === '#') return;
        var target = document.querySelector(href);
        if (!target) return;

        e.preventDefault();
        var navbarHeight = navbar.offsetHeight;
        var targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navbarHeight - 16;

        window.scrollTo({
          top: targetPosition,
          behavior: 'smooth',
        });
      });
    });
  }

  // ============================================================
  // Init
  // ============================================================
  function init() {
    setupScrollAnimations();
    animateCounters();
    setupSmoothScroll();
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

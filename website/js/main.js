/* 芥舟官网 · 交互 & 粒子特效 */
(function () {
  'use strict';

  /* ================= 全页粒子：水中沉光 + 落瓣（垫底、纯自主、克制的） ================= */
  (function ambient() {
    var canvas = document.getElementById('dust');
    if (!canvas) return;
    var ctx = canvas.getContext('2d');
    var W, H, DPR, parts = [];

    // 密度：约每 13px 宽一点，上限 130，下限 60——克制但有存在感
    function pickCount() { return Math.min(130, Math.max(60, Math.floor(innerWidth / 13))); }
    // 色板与标题渐变同源：青→浅青→月白（hsla 色调 180~205）
    function color() {
      var hue = 180 + Math.floor(Math.random() * 25);
      var light = 72 + Math.floor(Math.random() * 22);
      return { hue: hue, light: light, sat: 80 + Math.floor(Math.random() * 20) };
    }
    function make(initial) {
      var c = color();
      return {
        kind: Math.random() < 0.5 ? 'dot' : 'petal',   // 两种形态 1:1 混排
        x: Math.random() * innerWidth,
        y: initial ? Math.random() * innerHeight : -24,
        size: Math.random() * 5.2 + 2.6,              // 更大更醒目的粒子
        speed: Math.random() * 1.0 + 0.3,             // 缓速下坠
        drift: Math.random() * 0.55 - 0.275,
        sway: Math.random() * 0.7 + 0.2,
        ph: Math.random() * Math.PI * 2,
        swf: Math.random() * 0.02 + 0.008,
        rot: Math.random() * Math.PI * 2,
        rotSpd: (Math.random() - 0.5) * 0.04,         // 瓣片缓慢自转
        alpha: Math.random() * 0.42 + 0.3,
        hue: c.hue, sat: c.sat, light: c.light
      };
    }

    function resize() {
      DPR = Math.min(window.devicePixelRatio || 1, 2);
      W = canvas.width = innerWidth * DPR;
      H = canvas.height = innerHeight * DPR;
      canvas.style.width = innerWidth + 'px';
      canvas.style.height = innerHeight + 'px';
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      parts = Array.from({ length: pickCount() }, function () { return make(true); });
    }

    function drawDot(p) {
      ctx.save();
      ctx.shadowBlur = 9;
      ctx.shadowColor = 'hsla(' + p.hue + ',' + p.sat + '%,' + p.light + '%,' + Math.min(p.alpha, 0.9).toFixed(3) + ')';
      ctx.fillStyle = 'hsla(' + p.hue + ',' + p.sat + '%,' + p.light + '%,' + p.alpha.toFixed(3) + ')';
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size * 0.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
    function drawPetal(p) {
      var s = p.size;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot);
      ctx.fillStyle = 'hsla(' + p.hue + ',' + p.sat + '%,' + p.light + '%,' + (p.alpha * 0.75).toFixed(3) + ')';
      ctx.beginPath();
      ctx.moveTo(0, -s * 0.7);
      ctx.bezierCurveTo(s * 0.42, -s * 0.22, s * 0.42, s * 0.22, 0, s * 0.7);
      ctx.bezierCurveTo(-s * 0.42, s * 0.22, -s * 0.42, -s * 0.22, 0, -s * 0.7);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }

    function step() {
      ctx.clearRect(0, 0, W, H);
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        p.y += p.speed;
        p.x += p.drift + Math.sin(p.ph) * p.sway * 0.6;
        p.ph += p.swf;
        p.rot += p.rotSpd;
        if (p.y > H + 34) { parts[i] = make(false); continue; }
        if (p.x < -26) p.x = W + 20;
        if (p.x > W + 26) p.x = -20;
        if (p.kind === 'dot') drawDot(p); else drawPetal(p);
      }
      requestAnimationFrame(step);
    }
    resize();
    step();
    var rTimer;
    window.addEventListener('resize', function () { clearTimeout(rTimer); rTimer = setTimeout(resize, 200); });
  })();

  /* ================= 导航滚动态 ================= */
  var nav = document.querySelector('.nav');
  function onScroll() { nav.classList.toggle('scrolled', window.scrollY > 24); }
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  /* ================= 滚动登场 ================= */
  var revealEls = document.querySelectorAll('.section, .hl-item, .feat-text, .panel, .prow, .f-index');
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, { threshold: 0.12 });
  revealEls.forEach(function (el) { el.classList.add('reveal'); io.observe(el); });

  /* ================= 占位入口 toast ================= */
  var toast = document.querySelector('.toast');
  var toastTimer;
  window.showToast = function (msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('show'); }, 3200);
  };
  document.querySelectorAll('[data-coming]').forEach(function (el) {
    el.addEventListener('click', function (ev) {
      ev.preventDefault();
      window.showToast(el.getAttribute('data-coming'));
    });
  });
})();
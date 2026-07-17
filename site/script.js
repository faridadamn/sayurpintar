const revealElements = document.querySelectorAll('.reveal');

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12 }
);

revealElements.forEach((element) => observer.observe(element));

document.getElementById('year').textContent = new Date().getFullYear();

const waitlistForm = document.getElementById('waitlistForm');
const formStatus = document.getElementById('formStatus');

waitlistForm.addEventListener('submit', (event) => {
  event.preventDefault();
  const phoneInput = document.getElementById('phone');
  const phone = phoneInput.value.trim();

  if (phone.length < 9) {
    formStatus.textContent = 'Masukkan nomor WhatsApp yang valid.';
    return;
  }

  formStatus.textContent = 'Terima kasih. Nomor Anda sudah tercatat untuk versi demo.';
  waitlistForm.reset();
});
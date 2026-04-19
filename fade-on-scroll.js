document.addEventListener("DOMContentLoaded", () => {
    const fadeElements = document.querySelectorAll('.fade-text');
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            // When the element comes into the viewport
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target); // Stop observing once faded in
            }
        });
    }, {
        threshold: 0.1, // Triggers when 10% of the text is visible
        rootMargin: "0px 0px -10% 0px" // Triggers slightly before the very bottom of the screen
    });

    fadeElements.forEach(el => observer.observe(el));
});

document.addEventListener("DOMContentLoaded", () => {
    // Select all paragraphs that have the 'fade-text' class
    const fadeElements = document.querySelectorAll('.fade-text');
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            // When the text enters the bottom 15% of the screen
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                
                // Optional: Stop observing once it's visible so it stays visible
                observer.unobserve(entry.target);
            }
        });
    }, {
        threshold: 0.15, // Triggers when 15% of the text is visible
        rootMargin: "0px 0px -50px 0px"
    });

    fadeElements.forEach(el => observer.observe(el));
});

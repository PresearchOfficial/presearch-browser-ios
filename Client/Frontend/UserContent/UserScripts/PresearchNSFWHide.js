// Copyright 2026 The Presearch Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Hide NSFW toggle on presearch.com for App Store compliance
(function() {
    'use strict';

    // Inject CSS to hide NSFW-related elements
    const style = document.createElement('style');
    style.textContent = `
        /* Hide any element containing NSFW text or checkbox */
        [class*="nsfw" i],
        [id*="nsfw" i],
        [name*="nsfw" i],
        label[for*="nsfw" i],
        /* Hide settings rows/items containing NSFW */
        .setting-item:has([id*="nsfw" i]),
        .settings-row:has([id*="nsfw" i]),
        .menu-item:has([id*="nsfw" i]),
        div:has(> input[id*="nsfw" i]),
        div:has(> label[for*="nsfw" i]) {
            display: none !important;
        }
    `;

    // Insert as early as possible
    if (document.head) {
        document.head.appendChild(style);
    } else {
        document.documentElement.appendChild(style);
    }

    // Also observe for dynamically added elements
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) { // Element node
                    // Check if this element or its children contain NSFW
                    const nsfwElements = node.querySelectorAll ?
                        node.querySelectorAll('[class*="nsfw" i], [id*="nsfw" i], [name*="nsfw" i]') : [];
                    nsfwElements.forEach(function(el) {
                        // Hide the element and its parent container
                        el.style.display = 'none';
                        if (el.parentElement) {
                            el.parentElement.style.display = 'none';
                        }
                    });

                    // Check the node itself
                    if (node.id && node.id.toLowerCase().includes('nsfw')) {
                        node.style.display = 'none';
                    }
                    if (node.className && typeof node.className === 'string' &&
                        node.className.toLowerCase().includes('nsfw')) {
                        node.style.display = 'none';
                    }
                }
            });
        });
    });

    observer.observe(document.documentElement, {
        childList: true,
        subtree: true
    });
})();

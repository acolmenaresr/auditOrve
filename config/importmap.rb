# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "firebase/app", to: "https://www.gstatic.com/firebasejs/12.16.0/firebase-app.js", preload: false
pin "firebase/messaging", to: "https://www.gstatic.com/firebasejs/12.16.0/firebase-messaging.js", preload: false

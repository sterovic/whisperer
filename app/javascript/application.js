// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

// Enable Turbo Streams over WebSocket (ActionCable)
import { connectStreamSource, disconnectStreamSource } from "@hotwired/turbo"

// Optional: Configure Turbo settings
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.drive = true

// Theme change functionality
import { themeChange } from 'theme-change'
themeChange()

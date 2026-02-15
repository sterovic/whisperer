import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="search-autocomplete"
export default class extends Controller {
  static targets = ["input", "suggestions"];

  connect() {
    this.debounceTimer = null;
    this.selectedIndex = -1;
    this.handleClickOutside = this.handleClickOutside.bind(this);
    document.addEventListener("click", this.handleClickOutside);
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside);
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
  }

  onInput() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);

    const query = this.inputTarget.value.trim();
    if (query.length < 2) {
      this.hideSuggestions();
      return;
    }

    this.debounceTimer = setTimeout(() => {
      this.fetchSuggestions(query);
    }, 300);
  }

  onKeydown(event) {
    if (!this.hasSuggestionsTarget) return;
    const items = this.suggestionsTarget.querySelectorAll("[data-suggestion]");

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.selectedIndex = Math.min(
          this.selectedIndex + 1,
          items.length - 1,
        );
        this.highlightItem(items);
        break;
      case "ArrowUp":
        event.preventDefault();
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
        this.highlightItem(items);
        break;
      case "Enter":
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          event.preventDefault();
          this.selectSuggestion(items[this.selectedIndex].textContent.trim());
        }
        break;
      case "Escape":
        this.hideSuggestions();
        break;
    }
  }

  async fetchSuggestions(query) {
    try {
      const response = await fetch(
        `/video_searches/autocomplete?q=${encodeURIComponent(query)}`,
      );
      if (!response.ok) return;

      const suggestions = await response.json();
      this.renderSuggestions(suggestions);
    } catch (error) {
      console.warn("Autocomplete fetch error:", error);
    }
  }

  renderSuggestions(suggestions) {
    if (!this.hasSuggestionsTarget) return;

    if (suggestions.length === 0) {
      this.hideSuggestions();
      return;
    }

    this.selectedIndex = -1;
    this.suggestionsTarget.innerHTML = suggestions
      .map(
        (s) =>
          `<button type="button" data-suggestion class="w-full text-left px-3 py-2 text-sm hover:bg-base-200 cursor-pointer transition-colors" data-action="click->search-autocomplete#onSuggestionClick">${this.escapeHtml(s)}</button>`,
      )
      .join("");

    this.suggestionsTarget.classList.remove("hidden");
  }

  highlightItem(items) {
    items.forEach((item, index) => {
      item.classList.toggle("bg-base-200", index === this.selectedIndex);
    });
  }

  onSuggestionClick(event) {
    this.selectSuggestion(event.currentTarget.textContent.trim());
  }

  selectSuggestion(text) {
    this.inputTarget.value = text;
    this.hideSuggestions();
    this.inputTarget.focus();
  }

  hideSuggestions() {
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.add("hidden");
      this.suggestionsTarget.innerHTML = "";
    }
    this.selectedIndex = -1;
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions();
    }
  }

  escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }
}

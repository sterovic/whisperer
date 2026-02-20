import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { snapshots: Array };

  connect() {
    this.render();
  }

  render() {
    const snapshots = this.snapshotsValue;

    const W = 120;
    const H = 32;
    const pad = { top: 4, bottom: 4, left: 4, right: 4 };
    const chartW = W - pad.left - pad.right;
    const chartH = H - pad.top - pad.bottom;

    // Handle empty snapshots — draw a flat line
    if (snapshots.length === 0) {
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("width", W);
      svg.setAttribute("height", H);
      svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
      svg.style.overflow = "visible";
      svg.style.cursor = "default";
      const flatLine = document.createElementNS("http://www.w3.org/2000/svg", "line");
      flatLine.setAttribute("x1", pad.left);
      flatLine.setAttribute("y1", H - pad.bottom);
      flatLine.setAttribute("x2", W - pad.right);
      flatLine.setAttribute("y2", H - pad.bottom);
      flatLine.setAttribute("stroke", "#3b82f6");
      flatLine.setAttribute("stroke-width", "2");
      flatLine.setAttribute("stroke-opacity", "0.3");
      flatLine.setAttribute("stroke-linecap", "round");
      svg.append(flatLine);
      const chartEl = this.element.querySelector("[data-reach-chart-target='chart']");
      chartEl.innerHTML = "";
      chartEl.append(svg);
      return;
    }

    // Build cumulative reach values
    let cumulative = 0;
    const points = snapshots.map((s) => {
      cumulative += s.reach;
      return { ...s, cumulative };
    });

    const maxY = Math.max(...points.map((p) => p.cumulative), 1);

    const coords = points.map((p, i) => ({
      x:
        pad.left +
        (points.length === 1 ? chartW : (i / (points.length - 1)) * chartW),
      y: pad.top + chartH - (p.cumulative / maxY) * chartH,
      data: p,
    }));

    // Build SVG path
    const linePath = coords
      .map((c, i) => `${i === 0 ? "M" : "L"}${c.x},${c.y}`)
      .join(" ");
    const areaPath = `${linePath} L${coords[coords.length - 1].x},${H - pad.bottom} L${coords[0].x},${H - pad.bottom} Z`;

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", W);
    svg.setAttribute("height", H);
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
    svg.style.overflow = "visible";
    svg.style.cursor = "default";

    // Gradient
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
    const gradient = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "linearGradient",
    );
    gradient.setAttribute("id", `reach-grad-${this.element.id}`);
    gradient.setAttribute("x1", "0");
    gradient.setAttribute("y1", "0");
    gradient.setAttribute("x2", "0");
    gradient.setAttribute("y2", "1");
    const stop1 = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "stop",
    );
    stop1.setAttribute("offset", "0%");
    stop1.setAttribute("stop-color", "#3b82f6");
    stop1.setAttribute("stop-opacity", "0.12");
    const stop2 = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "stop",
    );
    stop2.setAttribute("offset", "100%");
    stop2.setAttribute("stop-color", "#3b82f6");
    stop2.setAttribute("stop-opacity", "0.02");
    gradient.append(stop1, stop2);
    defs.append(gradient);
    svg.append(defs);

    // Area fill
    const area = document.createElementNS("http://www.w3.org/2000/svg", "path");
    area.setAttribute("d", areaPath);
    area.setAttribute("fill", `url(#reach-grad-${this.element.id})`);
    svg.append(area);

    // Line
    const line = document.createElementNS("http://www.w3.org/2000/svg", "path");
    line.setAttribute("d", linePath);
    line.setAttribute("fill", "none");
    line.setAttribute("stroke", "#3b82f6");
    line.setAttribute("stroke-width", "1.5");
    line.setAttribute("stroke-linecap", "round");
    line.setAttribute("stroke-linejoin", "round");
    svg.append(line);

    // Dots for each data point (hidden by default)
    const dots = coords.map((c) => {
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      circle.setAttribute("cx", c.x);
      circle.setAttribute("cy", c.y);
      circle.setAttribute("r", "3");
      circle.setAttribute("fill", "#3b82f6");
      circle.setAttribute("opacity", "0");
      circle.classList.add("transition-opacity", "duration-150");
      svg.append(circle);
      return circle;
    });

    // Full-area overlay for hover — snaps to nearest point by X
    const overlay = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    overlay.setAttribute("x", "0");
    overlay.setAttribute("y", "0");
    overlay.setAttribute("width", W);
    overlay.setAttribute("height", H);
    overlay.setAttribute("fill", "transparent");

    let activeDot = null;

    overlay.addEventListener("mousemove", (e) => {
      const rect = svg.getBoundingClientRect();
      const mouseX = (e.clientX - rect.left) * (W / rect.width);

      let nearest = 0;
      let minDist = Infinity;
      coords.forEach((c, i) => {
        const dist = Math.abs(c.x - mouseX);
        if (dist < minDist) { minDist = dist; nearest = i; }
      });

      if (activeDot !== nearest) {
        if (activeDot !== null) dots[activeDot].setAttribute("opacity", "0");
        dots[nearest].setAttribute("opacity", "1");
        activeDot = nearest;
        this.showTooltip(coords[nearest]);
      }
    });

    overlay.addEventListener("mouseleave", () => {
      if (activeDot !== null) dots[activeDot].setAttribute("opacity", "0");
      activeDot = null;
      this.hideTooltip();
    });

    svg.append(overlay);

    const chartEl = this.element.querySelector("[data-reach-chart-target='chart']");
    chartEl.innerHTML = "";
    chartEl.append(svg);
  }

  showTooltip(coord) {
    const tooltip = this.element.querySelector(
      "[data-reach-chart-target='tooltip']",
    );
    if (!tooltip) return;

    const d = coord.data;
    const date = new Date(d.created_at);
    const dateStr = date.toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    tooltip.innerHTML = `
      <div class="text-xs font-medium">${dateStr}</div>
      <div class="flex flex-col gap-0.5 mt-1 text-[10px]">
        <span>Rank: <b>#${d.rank ?? "—"}</b></span>
        <span>Views: <b>${this.formatNumber(d.video_views)}</b></span>
        <span>Likes: <b>${d.like_count}</b></span>
        <span>Reach: <b>+${this.formatNumber(d.reach)}</b></span>
        <span>Total: <b>${this.formatNumber(d.cumulative)}</b></span>
      </div>
    `;

    tooltip.classList.remove("invisible", "opacity-0");
    tooltip.classList.add("opacity-100");

    // Position tooltip using fixed coordinates (escapes all overflow containers)
    const chartEl = this.element.querySelector("[data-reach-chart-target='chart']");
    const svg = chartEl.querySelector("svg");
    const svgRect = svg.getBoundingClientRect();
    const scaleX = svgRect.width / svg.viewBox.baseVal.width;
    const scaleY = svgRect.height / svg.viewBox.baseVal.height;

    const pointX = svgRect.left + coord.x * scaleX;
    const pointY = svgRect.top + coord.y * scaleY;

    const tooltipRect = tooltip.getBoundingClientRect();
    let left = pointX - tooltipRect.width / 2;
    left = Math.max(4, Math.min(left, window.innerWidth - tooltipRect.width - 4));
    const top = pointY - tooltipRect.height - 8;

    tooltip.style.left = `${left}px`;
    tooltip.style.top = `${top}px`;
  }

  hideTooltip() {
    const tooltip = this.element.querySelector(
      "[data-reach-chart-target='tooltip']",
    );
    if (!tooltip) return;
    tooltip.classList.add("invisible", "opacity-0");
    tooltip.classList.remove("opacity-100");
  }

  formatNumber(n) {
    if (n == null) return "—";
    if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M";
    if (n >= 1_000) return (n / 1_000).toFixed(1) + "K";
    return n.toLocaleString();
  }
}

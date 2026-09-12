// Procedural CRT micro-scanlines for authentic military cyberdeck displays.
// Low-overhead Canvas rendered to an offscreen image cache.
import QtQuick

Canvas {
    id: scanlines
    anchors.fill: parent
    opacity: 0.035
    antialiasing: false
    renderTarget: Canvas.Image

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = "#FFFFFF";
        for (let y = 0; y < height; y += 3) {
            ctx.fillRect(0, y, width, 1);
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}

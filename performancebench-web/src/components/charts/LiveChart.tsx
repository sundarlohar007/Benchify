import { useRef, useEffect } from 'react';
import { Chart } from 'chart.js';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  TimeScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import 'chartjs-adapter-date-fns';

ChartJS.register(
  CategoryScale,
  LinearScale,
  TimeScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
);

interface LiveChartProps {
  metric: string;
  color: string;
  yLabel?: string;
  onSample: (
    fn: (sample: Record<string, unknown>) => void,
  ) => () => void;
  extractValue: (sample: Record<string, unknown>) => number | null;
  maxPoints?: number;
}

const MAX_POINTS = 300; // 5 minutes at 1Hz

export function LiveChart({
  metric,
  color,
  yLabel,
  onSample,
  extractValue,
  maxPoints = MAX_POINTS,
}: LiveChartProps) {
  const chartRef = useRef<Chart | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  // Initialize Chart.js instance once
  useEffect(() => {
    if (!canvasRef.current) return;

    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;

    chartRef.current = new Chart(ctx, {
      type: 'line',
      data: {
        datasets: [
          {
            label: metric,
            data: [],
            borderColor: color,
            backgroundColor: color + '20',
            fill: false,
            tension: 0.1,
            pointRadius: 0,
            borderWidth: 1.5,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 0 },
        scales: {
          x: {
            type: 'time' as const,
            time: { tooltipFormat: 'HH:mm:ss' },
            ticks: { color: '#858585', font: { size: 11 }, maxTicksLimit: 10 },
            grid: { color: 'rgba(60, 60, 60, 0.25)' },
          },
          y: {
            beginAtZero: true,
            ticks: {
              color: '#858585',
              font: { size: 11 },
              callback: (v) => (typeof v === 'number' ? v.toFixed(1) : v),
            },
            title: {
              display: !!yLabel,
              text: yLabel ?? '',
              color: '#858585',
            },
            grid: { color: 'rgba(60, 60, 60, 0.25)' },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#2D2D30',
            titleColor: '#D4D4D4',
            bodyColor: '#D4D4D4',
            borderColor: '#3C3C3C',
            borderWidth: 1,
          },
        },
      },
    });

    return () => {
      chartRef.current?.destroy();
      chartRef.current = null;
    };
  }, [metric, color, yLabel]);

  // Append data points as they arrive
  useEffect(() => {
    return onSample((sample) => {
      if (!chartRef.current) return;
      const value = extractValue(sample);
      if (value === null || value === undefined) return;
      const timestamp =
        typeof sample.timestamp === 'number' ? sample.timestamp : Date.now();
      const chart = chartRef.current;
      const dataset = chart.data.datasets[0];
      dataset.data.push({ x: timestamp, y: value });

      // Keep only last N points (ring buffer)
      if (dataset.data.length > maxPoints) {
        dataset.data.shift();
      }

      chart.update('none'); // 'none' = no animation for live updates
    });
  }, [onSample, extractValue, maxPoints]);

  return <canvas ref={canvasRef} />;
}

import { useMemo } from 'react';
import { Line } from 'react-chartjs-2';
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

export interface TrendDataset {
  label: string;
  data: { x: number; y: number }[];
  borderColor: string;
  backgroundColor?: string;
  fill?: boolean;
  tension?: number;
  pointRadius?: number;
  borderWidth?: number;
  yAxisID?: string;
}

export interface TrendChartProps {
  datasets: TrendDataset[];
  yAxisLabel?: string;
  height?: number;
}

const darkThemeDefaults = {
  responsive: true,
  maintainAspectRatio: false,
  animation: { duration: 300 },
  interaction: {
    mode: 'index' as const,
    intersect: false,
  },
  scales: {
    x: {
      type: 'time' as const,
      time: {
        tooltipFormat: 'HH:mm:ss',
        displayFormats: {
          millisecond: 'HH:mm:ss.SSS',
          second: 'HH:mm:ss',
          minute: 'HH:mm',
          hour: 'HH:mm',
        },
      },
      ticks: {
        color: '#858585',
        font: { size: 11 },
        maxTicksLimit: 15,
      },
      grid: {
        color: 'rgba(60, 60, 60, 0.25)',
        drawBorder: false,
      },
    },
    y: {
      beginAtZero: true,
      ticks: {
        color: '#858585',
        font: { size: 11 },
        callback: (value: string | number) =>
          typeof value === 'number' ? value.toFixed(1) : value,
      },
      grid: {
        color: 'rgba(60, 60, 60, 0.25)',
        drawBorder: false,
      },
    },
  },
  plugins: {
    legend: {
      position: 'top' as const,
      labels: {
        color: '#D4D4D4',
        font: { size: 12 },
        usePointStyle: true,
        pointStyleWidth: 8,
        padding: 12,
      },
    },
    tooltip: {
      backgroundColor: '#2D2D30',
      titleColor: '#D4D4D4',
      bodyColor: '#D4D4D4',
      borderColor: '#3C3C3C',
      borderWidth: 1,
      padding: 8,
      cornerRadius: 4,
    },
  },
};

export function TrendChart({
  datasets,
  yAxisLabel,
  height = 250,
}: TrendChartProps) {
  const data = useMemo(() => ({ datasets }), [datasets]);

  const options = useMemo(() => {
    const base = { ...darkThemeDefaults };
    base.scales = {
      ...base.scales,
      y: {
        ...(base.scales.y as Record<string, unknown>),
        title: {
          display: !!yAxisLabel,
          text: yAxisLabel ?? '',
          color: '#858585',
          font: { size: 11 },
        },
      },
    };
    return base;
  }, [yAxisLabel]);

  return (
    <div style={{ height }} className="w-full">
      <Line data={data} options={options} />
    </div>
  );
}

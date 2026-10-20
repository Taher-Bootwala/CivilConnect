import React from "react";
import Sidebar from "@/components/Sidebar";

export default function DashboardOverviewPage() {
  const kpis = [
    { label: "Active Jobs", value: "18", change: "+4 this hr", color: "text-indigo-600" },
    { label: "Today's GMV", value: "₹42,850", change: "+14.2%", color: "text-slate-900" },
    { label: "Platform Net Revenue", value: "₹8,490", change: "15% comm + ₹49 fee", color: "text-emerald-600" },
    { label: "Pending KYC", value: "3", change: "Requires review", color: "text-amber-500" },
    { label: "Total Cash Exposure", value: "₹34,200", change: "Within ₹5k limit/worker", color: "text-teal-600" },
  ];

  const recentBookings = [
    {
      code: "CH-2026-921",
      customer: "Amit Shah",
      worker: "Ramesh Patel (Plumber)",
      status: "IN_PROGRESS",
      amount: "₹729.00",
      otp: "7429",
      address: "Flat 402, Shivalik Heights, CG Road",
    },
    {
      code: "CH-2026-884",
      customer: "Priya Mehta",
      worker: "Sunil Verma (Electrician)",
      status: "AMOUNT_PENDING_APPROVAL",
      amount: "₹1,249.00",
      otp: "Verified ✓",
      address: "12 Gulmohar Park, Bodakdev",
    },
    {
      code: "CH-2026-850",
      customer: "Deepak Trivedi",
      worker: "Karan Solanki (Carpenter)",
      status: "PAID",
      amount: "₹950.00",
      otp: "Verified ✓",
      address: "B-201 Titanium City Center, Satellite",
    },
  ];

  const cashAlertWorkers = [
    {
      name: "Ramesh Patel",
      trade: "Plumber",
      dues: "₹4,250",
      limit: "₹5,000",
      pct: 85,
      status: "Warning Sent (85%)",
    },
    {
      name: "Vikram Rathod",
      trade: "AC Technician",
      dues: "₹4,900",
      limit: "₹5,000",
      pct: 98,
      status: "Auto-Soft-Locked",
    },
  ];

  return (
    <div className="flex min-h-screen">
      <Sidebar currentPath="/" />

      <main className="flex-1 p-8 overflow-y-auto">
        <header className="flex items-center justify-between pb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-black text-slate-900 tracking-tight">Operations Dashboard</h2>
            <p className="text-sm text-slate-500 font-medium">Real-time marketplace telemetry and financial monitoring</p>
          </div>
          <div className="flex items-center gap-3">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              PostGIS Proximity Engine Live
            </span>
          </div>
        </header>

        {/* KPI Cards */}
        <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mt-6">
          {kpis.map((kpi, i) => (
            <div key={i} className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400">{kpi.label}</span>
              <div className={`text-2xl font-black mt-1 ${kpi.color}`}>{kpi.value}</div>
              <span className="text-xs text-slate-500 font-medium mt-1 inline-block">{kpi.change}</span>
            </div>
          ))}
        </div>

        {/* Live Booking Monitor & Cash Risk Guard */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-8">
          {/* Active Bookings Table */}
          <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 p-6 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-base text-slate-900">Live Booking Operations Feed</h3>
              <span className="text-xs font-semibold text-indigo-600 bg-indigo-50 px-2.5 py-1 rounded-lg">
                Synced via Supabase Realtime
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-slate-100 text-xs text-slate-400 uppercase font-bold">
                    <th className="pb-3">Booking Code</th>
                    <th className="pb-3">Customer</th>
                    <th className="pb-3">Professional</th>
                    <th className="pb-3">Status</th>
                    <th className="pb-3">Amount</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 font-medium">
                  {recentBookings.map((b, i) => (
                    <tr key={i} className="hover:bg-slate-50/60 transition">
                      <td className="py-3 font-bold text-slate-900">{b.code}</td>
                      <td className="py-3 text-slate-700">{b.customer}</td>
                      <td className="py-3 text-slate-700">{b.worker}</td>
                      <td className="py-3">
                        <span
                          className={`text-xs px-2.5 py-0.5 rounded-full font-bold ${
                            b.status === "PAID"
                              ? "bg-emerald-50 text-emerald-700"
                              : b.status === "IN_PROGRESS"
                              ? "bg-indigo-50 text-indigo-700"
                              : "bg-amber-50 text-amber-700"
                          }`}
                        >
                          {b.status}
                        </span>
                      </td>
                      <td className="py-3 font-bold text-slate-900">{b.amount}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Cash Exposure Alert Column */}
          <div className="bg-white rounded-2xl border border-slate-200/80 p-6 shadow-sm flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-bold text-base text-slate-900">₹5K Cash Limit Guard</h3>
                <span className="text-xs font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded">
                  Exposure Risk
                </span>
              </div>
              <p className="text-xs text-slate-500 mb-4">
                Workers with unpaid platform commission remitted from cash jobs:
              </p>

              <div className="space-y-4">
                {cashAlertWorkers.map((w, idx) => (
                  <div key={idx} className="p-3.5 bg-slate-50 rounded-xl border border-slate-200">
                    <div className="flex justify-between items-center text-sm font-bold text-slate-900">
                      <span>{w.name} ({w.trade})</span>
                      <span className="text-amber-600">{w.dues} / {w.limit}</span>
                    </div>
                    {/* Progress Bar */}
                    <div className="w-full bg-slate-200 h-2 rounded-full mt-2 overflow-hidden">
                      <div
                        className={`h-full ${w.pct >= 95 ? "bg-rose-500" : "bg-amber-500"}`}
                        style={{ width: `${w.pct}%` }}
                      ></div>
                    </div>
                    <div className="mt-2 flex justify-between text-xs text-slate-500">
                      <span>{w.status}</span>
                      <button className="text-indigo-600 font-bold hover:underline">Settle via Razorpay</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-slate-100 text-xs text-slate-400">
              Threshold configured to ₹5,000 under Section 9. Auto-warning at 80% (₹4,000).
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

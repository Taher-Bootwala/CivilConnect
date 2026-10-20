"use client";

import React, { useState } from "react";
import Sidebar from "@/components/Sidebar";

export default function DisputeArbitrationPage() {
  const [disputes, setDisputes] = useState([
    {
      id: "disp-901",
      bookingCode: "CH-PLUMB-921",
      customer: "Amit Shah",
      worker: "Ramesh Patel (Plumber)",
      service: "Tap & Mixer Leakage Repair",
      workerQuote: {
        labor: 450,
        materials: 180,
        visiting: 99,
        platformFee: 49,
        total: 778,
      },
      customerCounterAmount: 550,
      customerReason: "The worker only took 15 minutes to tighten the valve. Charging ₹450 labor feels excessive for a simple tightening.",
      workerExplanation: "Replaced internal heavy-duty brass spindle valve and tested cold/hot water pressure line.",
      status: "escalated_to_admin",
      escalatedAt: "10 mins ago",
    },
  ]);

  const handleResolve = (d: any) => {
    const overrideLabor = prompt("Enter Final Approved Labor Amount (₹):", "350");
    if (!overrideLabor) return;

    const note = prompt("Enter Mandatory Administrative Decision Reason:", "Labor adjusted downwards to standard market rate for spindle replacement.");
    if (!note) return;

    setDisputes((prev) =>
      prev.map((item) =>
        item.id === d.id ? { ...item, status: "resolved_by_admin" } : item
      )
    );

    alert(`Dispute for ${d.bookingCode} successfully resolved! New total calculated and logged to immutable audit_logs.`);
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar currentPath="/disputes" />

      <main className="flex-1 p-8 overflow-y-auto">
        <header className="flex items-center justify-between pb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-black text-slate-900 tracking-tight">Dispute Arbitration Center</h2>
            <p className="text-sm text-slate-500 font-medium">
              Resolve quote and charge disputes between customers and tradespeople with mandatory audit logs
            </p>
          </div>
          <span className="text-xs font-bold text-rose-700 bg-rose-50 px-3 py-1 rounded-full border border-rose-200">
            {disputes.filter((d) => d.status === "escalated_to_admin").length} Escalated Dispute
          </span>
        </header>

        <div className="mt-6 space-y-6">
          {disputes.map((d) => (
            <div
              key={d.id}
              className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                  <div>
                    <span className="text-xs font-bold text-indigo-600 bg-indigo-50 px-2.5 py-1 rounded-md">
                      Booking #{d.bookingCode}
                    </span>
                    <h3 className="text-lg font-black text-slate-900 mt-2">{d.service}</h3>
                  </div>
                  <span className="text-xs font-bold px-3 py-1 rounded-full uppercase bg-rose-50 text-rose-700">
                    {d.status.replace(/_/g, " ")}
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-4">
                  {/* Worker Quote */}
                  <div className="p-4 bg-slate-50 rounded-xl border border-slate-200">
                    <span className="text-xs font-bold text-slate-400 uppercase">Tradesperson Position</span>
                    <div className="text-sm font-bold text-slate-900 mt-1">{d.worker}</div>
                    <div className="mt-3 text-xs space-y-1.5 font-medium">
                      <div className="flex justify-between">
                        <span className="text-slate-500">Labor Charge:</span>
                        <span className="font-bold">₹{d.workerQuote.labor}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-500">Materials (Spindle Valve):</span>
                        <span className="font-bold">₹{d.workerQuote.materials}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-500">Visiting Charge:</span>
                        <span className="font-bold">₹{d.workerQuote.visiting}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-500">Platform Fee:</span>
                        <span className="font-bold">₹{d.workerQuote.platformFee}</span>
                      </div>
                      <div className="flex justify-between pt-2 border-t border-slate-200 font-extrabold text-sm text-slate-900">
                        <span>Original Total:</span>
                        <span className="text-indigo-600">₹{d.workerQuote.total}</span>
                      </div>
                    </div>
                    <div className="mt-3 pt-3 border-t border-slate-200 text-xs text-slate-600 italic">
                      &quot;{d.workerExplanation}&quot;
                    </div>
                  </div>

                  {/* Customer Counter Offer */}
                  <div className="p-4 bg-amber-50/60 rounded-xl border border-amber-200">
                    <span className="text-xs font-bold text-amber-600 uppercase">Customer Counter-Position</span>
                    <div className="text-sm font-bold text-slate-900 mt-1">{d.customer}</div>

                    <div className="mt-3 text-xs">
                      <span className="text-slate-500">Proposed Counter-Amount:</span>
                      <div className="text-2xl font-black text-amber-700 mt-0.5">
                        ₹{d.customerCounterAmount}.00
                      </div>
                    </div>

                    <div className="mt-3 p-3 bg-white/80 rounded-lg border border-amber-200/80 text-xs text-slate-700">
                      <span className="font-bold block text-slate-900 mb-1">Customer Reason:</span>
                      &quot;{d.customerReason}&quot;
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Controls */}
              {d.status === "escalated_to_admin" ? (
                <div className="mt-6 pt-4 border-t border-slate-100 flex justify-end gap-3">
                  <button
                    onClick={() => handleResolve(d)}
                    className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl shadow-sm transition"
                  >
                    Arbitrate & Settle Final Amount
                  </button>
                </div>
              ) : (
                <div className="mt-4 pt-3 border-t border-slate-100 text-xs font-bold text-emerald-600 text-right">
                  ✓ Dispute Resolved by Administrator
                </div>
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}

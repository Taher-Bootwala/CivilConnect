"use client";

import React, { useState } from "react";
import Sidebar from "@/components/Sidebar";

export default function ServicesConfigPage() {
  const [services, setServices] = useState([
    {
      id: "s1",
      category: "Plumbing Services",
      name: "Tap & Mixer Leakage Repair",
      visitingCharge: 99,
      minEstimate: 150,
      maxEstimate: 450,
      commissionPct: 15.0,
      fixedFee: 49,
      isActive: true,
    },
    {
      id: "s2",
      category: "Plumbing Services",
      name: "Drainage & Pipe Unclogging",
      visitingCharge: 99,
      minEstimate: 250,
      maxEstimate: 900,
      commissionPct: 15.0,
      fixedFee: 49,
      isActive: true,
    },
    {
      id: "s3",
      category: "Electrical Repairs",
      name: "Switchboard & Wiring Short Circuit",
      visitingCharge: 99,
      minEstimate: 199,
      maxEstimate: 800,
      commissionPct: 15.0,
      fixedFee: 49,
      isActive: true,
    },
    {
      id: "s4",
      category: "AC & Appliance Service",
      name: "AC Jet Cleaning & Foam Wash",
      visitingCharge: 199,
      minEstimate: 499,
      maxEstimate: 1200,
      commissionPct: 15.0,
      fixedFee: 49,
      isActive: true,
    },
  ]);

  const handleUpdate = (id: string, name: string) => {
    const newCommission = prompt(`Enter new Commission % for ${name}:`, "15.0");
    if (!newCommission) return;

    const newFixedFee = prompt(`Enter new Fixed Platform Fee (₹) for ${name}:`, "49");
    if (!newFixedFee) return;

    setServices((prev) =>
      prev.map((s) =>
        s.id === id
          ? {
              ...s,
              commissionPct: parseFloat(newCommission),
              fixedFee: parseInt(newFixedFee, 10),
            }
          : s
      )
    );

    alert(`Pricing configuration updated for ${name}! Versioned snapshot will apply to future bookings.`);
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar currentPath="/services" />

      <main className="flex-1 p-8 overflow-y-auto">
        <header className="flex items-center justify-between pb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-black text-slate-900 tracking-tight">Services & Revenue Model Configuration</h2>
            <p className="text-sm text-slate-500 font-medium">
              Configure per-service commission percentages, fixed customer platform fees, and visiting charge policies
            </p>
          </div>
          <button
            onClick={() => alert("Creating a new service category...")}
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl shadow-sm transition"
          >
            + Add New Service
          </button>
        </header>

        <div className="mt-6 bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200 text-xs text-slate-400 uppercase font-bold">
                <th className="py-3 px-6">Service Name</th>
                <th className="py-3 px-6">Category</th>
                <th className="py-3 px-6">Visiting Fee</th>
                <th className="py-3 px-6">Estimate Range</th>
                <th className="py-3 px-6">Commission %</th>
                <th className="py-3 px-6">Platform Fee</th>
                <th className="py-3 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 font-medium">
              {services.map((s) => (
                <tr key={s.id} className="hover:bg-slate-50/70 transition">
                  <td className="py-4 px-6 font-bold text-slate-900">{s.name}</td>
                  <td className="py-4 px-6 text-slate-500">{s.category}</td>
                  <td className="py-4 px-6 font-bold text-slate-800">₹{s.visitingCharge}</td>
                  <td className="py-4 px-6 text-slate-600">₹{s.minEstimate} – ₹{s.maxEstimate}</td>
                  <td className="py-4 px-6">
                    <span className="px-2.5 py-1 bg-indigo-50 text-indigo-700 font-bold rounded-lg text-xs">
                      {s.commissionPct}%
                    </span>
                  </td>
                  <td className="py-4 px-6">
                    <span className="px-2.5 py-1 bg-emerald-50 text-emerald-700 font-bold rounded-lg text-xs">
                      +₹{s.fixedFee}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-right">
                    <button
                      onClick={() => handleUpdate(s.id, s.name)}
                      className="text-xs font-bold text-indigo-600 hover:underline"
                    >
                      Edit Rates
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}

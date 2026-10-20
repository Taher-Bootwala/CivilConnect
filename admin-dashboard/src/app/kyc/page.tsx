"use client";

import React, { useState } from "react";
import Sidebar from "@/components/Sidebar";

export default function KycVerificationPage() {
  const [applications, setApplications] = useState([
    {
      id: "kyc-101",
      name: "Sunil Verma",
      trade: "Electrician",
      phone: "+91 98251 09876",
      experience: "7 years",
      idType: "Aadhaar Card",
      idNumber: "XXXX-XXXX-4912",
      frontUrl: "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=400",
      submittedAt: "25 mins ago",
      status: "pending",
    },
    {
      id: "kyc-102",
      name: "Raju Sharma",
      trade: "Carpenter",
      phone: "+91 98980 12345",
      experience: "12 years",
      idType: "PAN Card",
      idNumber: "ABCDE1234F",
      frontUrl: "https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=400",
      submittedAt: "1 hour ago",
      status: "pending",
    },
    {
      id: "kyc-103",
      name: "Mukesh Solanki",
      trade: "Plumber",
      phone: "+91 97234 56789",
      experience: "4 years",
      idType: "Aadhaar Card",
      idNumber: "XXXX-XXXX-8821",
      frontUrl: "https://images.unsplash.com/photo-1544717305-2782549b5136?w=400",
      submittedAt: "Yesterday",
      status: "verified",
    },
  ]);

  const handleApprove = (id: string, name: string) => {
    setApplications((prev) =>
      prev.map((app) => (app.id === id ? { ...app, status: "verified" } : app))
    );
    alert(`KYC for ${name} approved. Profile marked as verified in labor_profiles table.`);
  };

  const handleReject = (id: string, name: string) => {
    const reason = prompt("Enter mandatory written rejection reason for compliance audit log:");
    if (!reason) return;
    setApplications((prev) =>
      prev.map((app) => (app.id === id ? { ...app, status: "rejected" } : app))
    );
    alert(`KYC for ${name} rejected with reason: "${reason}". Notification sent to worker.`);
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar currentPath="/kyc" />

      <main className="flex-1 p-8 overflow-y-auto">
        <header className="flex items-center justify-between pb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-black text-slate-900 tracking-tight">Worker KYC Verification</h2>
            <p className="text-sm text-slate-500 font-medium">
              Review government identity documents and banking details before activating worker dispatch
            </p>
          </div>
          <span className="text-xs font-bold text-amber-700 bg-amber-50 px-3 py-1 rounded-full border border-amber-200">
            {applications.filter((a) => a.status === "pending").length} Pending Applications
          </span>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mt-6">
          {applications.map((app) => (
            <div
              key={app.id}
              className={`bg-white rounded-2xl border p-5 shadow-sm transition flex flex-col justify-between ${
                app.status === "verified"
                  ? "border-emerald-200"
                  : app.status === "rejected"
                  ? "border-rose-200 opacity-60"
                  : "border-slate-200"
              }`}
            >
              <div>
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                    {app.trade} • {app.experience}
                  </span>
                  <span
                    className={`text-xs px-2.5 py-0.5 rounded-full font-bold uppercase ${
                      app.status === "verified"
                        ? "bg-emerald-50 text-emerald-700"
                        : app.status === "rejected"
                        ? "bg-rose-50 text-rose-700"
                        : "bg-amber-50 text-amber-700"
                    }`}
                  >
                    {app.status}
                  </span>
                </div>

                <h3 className="text-lg font-black text-slate-900 mt-2">{app.name}</h3>
                <p className="text-xs text-slate-500 font-medium">{app.phone}</p>

                <div className="mt-4 p-3 bg-slate-50 rounded-xl border border-slate-100 text-xs space-y-1">
                  <div className="flex justify-between">
                    <span className="text-slate-500">Document Type:</span>
                    <span className="font-bold text-slate-900">{app.idType}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Masked ID:</span>
                    <span className="font-mono font-bold text-slate-900">{app.idNumber}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Submitted:</span>
                    <span className="text-slate-600">{app.submittedAt}</span>
                  </div>
                </div>

                {/* Document Thumbnail Preview */}
                <div className="mt-4">
                  <span className="text-xs font-bold text-slate-500 block mb-1">Attached Government Proof:</span>
                  <div className="h-32 w-full bg-slate-100 rounded-xl overflow-hidden relative border border-slate-200 group">
                    <img
                      src={app.frontUrl}
                      alt="ID Document"
                      className="w-full h-full object-cover group-hover:scale-105 transition"
                    />
                    <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition flex items-center justify-center text-white text-xs font-bold">
                      Click to Enlarge Full Res
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              {app.status === "pending" ? (
                <div className="flex gap-2 mt-5 pt-4 border-t border-slate-100">
                  <button
                    onClick={() => handleReject(app.id, app.name)}
                    className="flex-1 py-2 text-xs font-bold text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-xl transition"
                  >
                    Reject
                  </button>
                  <button
                    onClick={() => handleApprove(app.id, app.name)}
                    className="flex-1 py-2 text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl shadow-sm transition"
                  >
                    Approve Worker
                  </button>
                </div>
              ) : (
                <div className="mt-4 pt-3 border-t border-slate-100 text-center text-xs font-bold text-slate-400">
                  Application Finalized
                </div>
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}

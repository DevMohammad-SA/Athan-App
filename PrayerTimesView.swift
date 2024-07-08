//
//  PrayerTimesView.swift
//  Athan App
//
//  Created by Mohammad on 02/07/2024.
//
import SwiftUI
import Adhan
import Combine
import CoreLocation

struct PrayerTimesView: View {
    @State private var currentTime = Date()
    @ObservedObject var prayerTimes = PrayerTimesClass()
    @Environment(\.colorScheme) var colorScheme
    @State private var nextPrayer: (String, Date)? = nil
    @State private var hijriDate: String = ""
    let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    HStack {
                        Text(hijriDate)
                        Image(systemName: "calendar")
                    }
                    .padding(.top, 25)

                    HStack {
                        Text(prayerTimes.city ?? "جاري البحث عن أقرب موقع...")
                        Image(systemName: "location")
                    }

                    if let nextPrayer = nextPrayer {
                        GroupBox {
                            VStack {
                                Text("بقي على")
                                Text("\(nextPrayer.0)")
                                    .font(.largeTitle)
                                Text("\(prayerTimes.formattedPrayerTime(nextPrayer.1))")
                                Text("\(timeRemaining(until: nextPrayer.1).style)")
                                    .onReceive(timerPublisher) { _ in
                                        currentTime = Date()
                                    }
                            }
                            .frame(width: 100.0)
                        }
                        .backgroundStyle(.groupbox)
                    }

                    VStack {
                        rtlGroupBox(prayerIcon: "sun.horizon", prayerName: "الفجر", prayerTime: formattedPrayerTime(prayerTimes.prayers?.fajr))
                        rtlGroupBox(prayerIcon: "sunrise", prayerName: "الشروق", prayerTime: formattedPrayerTime(prayerTimes.prayers?.sunrise))
                        rtlGroupBox(prayerIcon: "sun.max", prayerName: "الظهر", prayerTime: formattedPrayerTime(prayerTimes.prayers?.dhuhr))
                        rtlGroupBox(prayerIcon: "sun.min", prayerName: "العصر", prayerTime: formattedPrayerTime(prayerTimes.prayers?.asr))
                        rtlGroupBox(prayerIcon: "sunset", prayerName: "المغرب", prayerTime: formattedPrayerTime(prayerTimes.prayers?.maghrib))
                        rtlGroupBox(prayerIcon: "moon", prayerName: "العشاء", prayerTime: formattedPrayerTime(prayerTimes.prayers?.isha))
                    }
                    .padding(.horizontal, 50.0)
                    .backgroundStyle(.groupbox)
                    .fontWeight(.bold)
                }
                .fontWeight(.bold)


                Spacer()

                HStack {
                    if colorScheme == .dark {
                        Image("AppLogoLight")
                            .resizable(resizingMode: .stretch)
                            .frame(width: 100.0, height: 100.0)
                            .cornerRadius(20)
                    } else {
                        Image("AppLogoDark")
                            .resizable(resizingMode: .stretch)
                            .frame(width: 100.0, height: 100.0)
                            .cornerRadius(20)
                    }

                    Spacer()
                    Text("ملاحظة : التطبيق لازال في طور التجربة وبإذن الله تعالى سيُتاح للتحميل عمّا قريب")
                        .multilineTextAlignment(.trailing)
                }
                .padding()
            }
            .refreshable {
                self.refresh()
            }
            .onAppear {
                prayerTimes.startUpdatingLocation()
                updateNextPrayer()
                updateHijriDate()
            }
            .onDisappear {
                prayerTimes.stopUpdatingLocation()
            }
            .foregroundColor(.font)
            .background(Color.accent)
        }
    }

    private func updateNextPrayer() {
        if let nextPrayer = prayerTimes.getNextPrayer() {
            self.nextPrayer = nextPrayer
        } else {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            let coordinates = CLLocationManager().location!.coordinate
            let coords = Coordinates(latitude: coordinates.latitude, longitude: coordinates.longitude)
            let params = CalculationMethod.ummAlQura.params
            if let prayerTimesTomorrow = PrayerTimes(coordinates: coords, date: components, calculationParameters: params) {
                self.nextPrayer = [
                    ("الفجر", prayerTimesTomorrow.fajr),
                    ("الشروق", prayerTimesTomorrow.sunrise),
                    ("الظهر", prayerTimesTomorrow.dhuhr),
                    ("العصر", prayerTimesTomorrow.asr),
                    ("المغرب", prayerTimesTomorrow.maghrib),
                    ("العشاء", prayerTimesTomorrow.isha)
                ].first
            }
        }
    }

    private func updateHijriDate() {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let date = Date()
        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ar_SA")
        hijriDate = formatter.string(from: date)
    }

    private func refresh() {
        prayerTimes.startUpdatingLocation()
        updateNextPrayer()
        updateHijriDate()
    }
}

func timeRemaining(until date: Date) -> String {
    let now = Date()
    let timeInterval = date.timeIntervalSince(now)
    if timeInterval <= 0 {
        return "Now"
    }
    let hours = Int(timeInterval) / 3600
    let minutes = (Int(timeInterval) % 3600) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

func formattedPrayerTime(_ prayerTime: Date?) -> String {
    guard let prayerTime = prayerTime else { return "N/A" }
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.timeZone = TimeZone.current
    return formatter.string(from: prayerTime)
}

extension PrayerTimesClass {
    func prayerTimesArray() -> [(String, Date)] {
        guard let prayers = prayers else { return [] }
        return [
            ("الفجر", prayers.fajr),
            ("الشروق", prayers.sunrise),
            ("الظهر", prayers.dhuhr),
            ("العصر", prayers.asr),
            ("المغرب", prayers.maghrib),
            ("العشاء", prayers.isha)
        ]
    }
}

#Preview {
    PrayerTimesView()
}

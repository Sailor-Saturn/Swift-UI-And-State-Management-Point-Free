import SwiftUI
import Combine
import ComposableArchitecture


struct ContentView: View {
    @ObservedObject var state: AppState
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(state: self.state)) {
                    Text("Counter Demo")
                }
                NavigationLink(destination: FavoritePrimes(
                    favoritePrimes: $state.favoritePrimes,
                    activityFeed: $state.activityFeed)) {
                    Text("Favourite Primes")
                }
            }
            .navigationBarTitle("State Management")
        }
    }
}

private func ordinal(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter.string(for: n) ?? ""
}

class AppState: ObservableObject {
    @Published var count = 0
    @Published var favoritePrimes: [Int] = []
    @Published var loggedInUser: User?
    @Published var activityFeed: [Activity] = []
    
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
    
    struct Activity {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }
}

extension AppState {
    func addFavoritePrime() {
        self.favoritePrimes.append (self.count)
        self.activityFeed.append(
            Activity(
                timestamp: Date(),
                type: .addedFavoritePrime(self.count)
            )
        )
    }
    
    func removeFavoritePrime(_ prime: Int) {
        self.favoritePrimes.removeAll(where: { $0 == prime })
        self.activityFeed.append(
            Activity(
                timestamp: Date(),
                type: .removedFavoritePrime (prime)
            )
        )
    }
    
    func removeFavoritePrime() {
        self.removeFavoritePrime(self .count)
    }
    
    func removeFavoritePrimes(at indexSet: IndexSet) {
        for index in indexSet {
            self.removeFavoritePrime(self.favoritePrimes [index])
        }
    }
}

struct CounterView: View {
    @ObservedObject var state: AppState
    @State var isPrimeModalShown: Bool = false
    @State var isAlertNthPrimeShown: Bool = false
    @State var alertNthPrime: Int?
    @State var isNthPrimeBtnDisabled: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {self.state.count -= 1}) { Text("-")}
                Text("\(self.state.count)")
                Button(action: {self.state.count += 1}) { Text("+")}
            }
            Button(action: {
                self.isPrimeModalShown = true
            }) { Text("Is this prime?")}
            Button(action: self.nthPrimeButtonAction) {
                Text("What's the \(ordinal(self.state.count)) prime?")
            }.disabled(self.isNthPrimeBtnDisabled)
        }
        .font(.title)
        .navigationBarTitle("Counter Demo")
        .sheet(isPresented: self.$isPrimeModalShown, onDismiss: { self.isPrimeModalShown = false }) {
            IsPrimeModalView(state: self.state)
        }
        .alert(isPresented: self.$isAlertNthPrimeShown) {
            Alert(
                title: Text("Prime"),
                message: Text("The \(ordinal(self.state.count)) prime is \(self.alertNthPrime ?? 0)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Fire effect, no handling of side effect, no way of testing
    func nthPrimeButtonAction() {
        self.isNthPrimeBtnDisabled = true
        nthPrime(self.state.count) { prime in
            self.alertNthPrime = prime
            self.isAlertNthPrimeShown = true
            self.isNthPrimeBtnDisabled = false
        }
    }
}

private func isPrime(_ p: Int) -> Bool {
    if p <= 1 { return false }
    if p <= 3 { return true }
    for i in 2...Int(sqrt(Float(p))) {
        if p % i == 0 { return false}
    }
    return true
}

func nthPrime(_ n: Int, callback: @escaping (Int?) -> Void) -> Void {
    wolframAlpha(query: "prime \(n)") { result in
        callback(
            result
                .flatMap {
                    $0.queryresult
                        .pods
                        .first(where: { $0.primary == .some(true) })?
                        .subpods
                        .first?
                        .plaintext
                }
                .flatMap(Int.init)
        )
    }
}

// Lets split the views into smaller components
// MARK: IsPrimeModalView
struct IsPrimeModalView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack {
            if isPrime(self.state.count) {
                Text("SOMEBODY HEEEELPPPP THIS GUY HAS A  PRIMEEEE \(self.state.count)")
                if self.state.favoritePrimes.contains(self.state.count) {
                    Button(action: {
                        self.state.favoritePrimes.removeAll { $0 == self.state.count }
                        self.state.activityFeed.append(.init(timestamp: Date(),
                                                             type: .removedFavoritePrime(self.state.count)))
                    }) {
                        Text("Remove From Favorites")
                    }
                } else {
                    Button(action: {
                        self.state.favoritePrimes.append(self.state.count)
                        self.state.activityFeed.append(.init(timestamp: Date(), type:
                                .addedFavoritePrime (self.state.count)))
                    }) {
                        Text("Save To Favorites")
                    }
                }
                
            } else {
                Text("Phew, \(self.state.count) is not a prime  we're safe")
            }
            
            
        }
    }
}

// MARK: FavoritePrimesView
struct FavoritePrimes: View {
    // Receives all app state even though it only needs to handle the favorites prime
    //    @ObservedObject var state: AppState
    @Binding var favoritePrimes: [Int]
    @Binding var activityFeed: [AppState.Activity]
    
    var body: some View {
        List{
            ForEach(favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let prime = favoritePrimes[index]
                    favoritePrimes.remove(at: index)
                    activityFeed.append(.init(timestamp: Date(), type:
                            .removedFavoritePrime (prime)))
                }
            }
        }
        .navigationBarTitle(Text("Favorite Primes"))
    }
}

struct WolframAlphaResult: Decodable {
    let queryresult: QueryResult
    
    struct QueryResult: Decodable {
        let pods: [Pod]
        
        struct Pod: Decodable {
            let primary: Bool?
            let subpods: [SubPod]
            
            struct SubPod: Decodable {
                let plaintext: String
            }
        }
    }
}

func wolframAlpha(query: String, callback: @escaping (WolframAlphaResult?) -> Void) -> Void {
    var components = URLComponents(string: "https://api.wolframalpha.com/v2/query")!
    components.queryItems = [
        URLQueryItem(name: "input", value: query),
        URLQueryItem(name: "format", value: "plaintext"),
        URLQueryItem(name: "output", value: "JSON"),
        URLQueryItem(name: "appid", value: "6HQW2P-JVRK3XWGK7"),
    ]
    
    URLSession.shared.dataTask(with: components.url(relativeTo: nil)!) { data, response, error in
        callback(
            data
                .flatMap { try? JSONDecoder().decode(WolframAlphaResult.self, from: $0) }
        )
    }
    .resume()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(state: AppState())
    }
}

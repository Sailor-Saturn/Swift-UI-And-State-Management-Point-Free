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
                NavigationLink(destination: FavoritePrimes(state: self.state)) {
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
}

struct CounterView: View {
    @ObservedObject var state: AppState
    @State var isPrimeModalShown: Bool = false
    @State var isAlertNthPrimeShown: Bool = false
    @State var alertNthPrime: Int?

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
            Button(action: {
                nthPrime(self.state.count) { prime in
                    self.alertNthPrime = prime
                    self.isAlertNthPrimeShown = true
                }
            }) {
                Text("What's the \(ordinal(self.state.count)) prime?")
            }
        }
        .font(.title)
        .navigationBarTitle("Counter Demo")
        .sheet(isPresented: self.$isPrimeModalShown, onDismiss: { self.isPrimeModalShown = false }) {
            IsPrimeModalView()
        }
        .alert(isPresented: self.$isAlertNthPrimeShown) {
            Alert(
                title: Text("Prime"),
                message: Text("The \(ordinal(self.state.count)) prime is \(self.alertNthPrime ?? 0)"),
                dismissButton: .default(Text("OK"))
            )
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
                    Button(action: {self.state.favoritePrimes.removeAll { fav in
                        fav == self.state.count
                    }}) {
                        Text("Remove From Favorites")
                    }
                } else {
                    Button(action: {self.state.favoritePrimes.append(self.state.count)}) {
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
    @ObservedObject var state: AppState

      var body: some View {
          List{
              ForEach(self.state.favoritePrimes, id: \.self) { prime in
                  Text("\(prime)")
              }
              .onDelete { indexSet in
                  for index in indexSet {
                      self.state.favoritePrimes.remove(at: index)
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

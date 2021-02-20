# Absinthe Socket Transport

A `NetworkTransport` implementation for using Phoenix + Absinthe with Apollo's Swift library.

**Warning**: This library is experimental, and developed by an _advanced beginner_ in Swift. Contributions are welcome.

---

### When would you use this package?

* You use the [Absinthe](https://github.com/absinthe-graphql/absinthe) GraphQL implementation for the [Elixir](https://elixir-lang.org/) language
* You expose Absinthe in a [Phoenix](https://phoenixframework.org/) app using [Absinthe.Phoenix](https://github.com/absinthe-graphql/absinthe_phoenix)
* You use websockets (via Phoenix channels) to run GraphQL subscriptions (and optionally regular queries + mutations)
* You wish to connect to this GraphQL server from a Swift application using [Apollo iOS](https://github.com/apollographql/apollo-ios) (which also serves macOS, etc.)

The Apollo iOS library uses `NetworkTransport`s to implement sending/receiving GraphQL operations. This package provides `AbsintheSocketTransport`, an implementation of `NetworkTransport` that communicates via websockets in a Phoenix/Absinthe-friendly way. Use this library if you would prefer not to modify the server using something like [absinthe_apollo_sockets](https://github.com/easco/absinthe_apollo_sockets).

---

### Installation

This package was created using Swift Package Manager. If you require the use of a different package manager, please help me to implement any requirements.

```
.package(url: "https://github.com/aj-foster/absinthe-socket-transport.git", .upToNextMinor(from: "0.0.1"))
```

Note that this package has fairly strict version dependencies on `SwiftPhoenixClient` and `Apollo`. If you require the use of different versions, please help me to test those packages.

### Usage



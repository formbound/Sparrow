import HTTP
import Sparrow

func simpleRouter() -> Router {
    let router = Router()
    
    router.get { _ in
        Response(status: .ok)
    }

    router.get("user") { _ in
        Response(status: .ok)
    }

    router.get("user", %"id") { request in
        let id = try request.uri.parameter("id")
        return Response(status: .ok, body: id)
    }
    
    return router
}
